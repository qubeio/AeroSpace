@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMove_swapWindows() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    func testMoveInto_findTopMostContainerWithRightOrientation() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                }
            }
        }

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .h_tiles([
                    .window(1),
                    .h_tiles([
                        .window(2),
                    ]),
                ]),
            ]),
        )
    }

    func testMove_mru() async throws {
        var window3: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    window3 = TestWindow.new(id: 3, parent: $0)
                }
                TestWindow.new(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .v_tiles([
                    .h_tiles([
                        .window(1),
                        .window(2),
                        .window(3),
                    ]),
                    .window(4),
                ]),
            ]),
        )
    }

    func testSwap_preserveWeight() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let window1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let window2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 2)
        _ = window2.focusWindow()

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(window2.hWeight, 2)
        assertEquals(window1.hWeight, 1)
    }

    func testMoveIn_newWeight() async throws {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0, adaptiveWeight: 1)
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 2)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 1)
            }
        }
        _ = window1.focusWindow()

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(window2.hWeight, 1)
        assertEquals(window2.vWeight, 1)
        assertEquals(window1.vWeight, 1)
        assertEquals(window1.hWeight, 1)
    }

    func testCreateImplicitContainer() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .tiles
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(1), .window(3)]),
                ]),
            ]),
        )
        assertEquals(result.exitCode, 0)
        XCTAssertEqual(workspace.rootTilingContainer.layout, .tiles)
    }

    func testCreateImplicitContainer_preservesBspMovingLeft() async throws {
        try await assertBoundaryMovePreservesBsp(.left)
    }

    func testCreateImplicitContainer_preservesBspMovingRight() async throws {
        try await assertBoundaryMovePreservesBsp(.right)
    }

    func testCreateImplicitContainer_preservesBspMovingUp() async throws {
        try await assertBoundaryMovePreservesBsp(.up)
    }

    func testCreateImplicitContainer_preservesBspMovingDown() async throws {
        try await assertBoundaryMovePreservesBsp(.down)
    }

    func testStop_onRootNode() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = try await parseCommand("move --boundaries-action stop left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .window(2), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode, 0)
    }

    func testStop_onRootNode_withOppositeOrientation() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = try await parseCommand("move --boundaries-action stop up").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .window(2), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode, 0)
    }

    func testStop_onRootNode_whenNoBoundary() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = try await parseCommand("move --boundaries-action stop left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(2), .window(1), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode, 0)
    }

    func testStop_onInnerNode() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
        }

        let result = try await parseCommand("move --boundaries-action stop right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .v_tiles([.window(3)]), .window(2)]),
            ]),
        )
        assertEquals(result.exitCode, 0)
    }

    func testFail() async throws {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = try await parseCommand("move --boundaries-action fail left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .window(2), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode, 1)
    }

    func testMoveOut() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
                TestWindow.new(id: 4, parent: $0)
            }
        }

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .v_tiles([
                    .window(3),
                    .window(4),
                ]),
            ]),
        )
    }

    func testMoveOutWithNormalization_right() async throws {
        config.enableNormalizationFlattenContainers = true

        let workspace = Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            assertEquals(TestWindow.new(id: 2, parent: $0.rootTilingContainer).focusWindow(), true)
        }

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ]),
        )
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveOutWithNormalization_left() async throws {
        config.enableNormalizationFlattenContainers = true

        let workspace = Workspace.get(byName: name).apply {
            assertEquals(TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
        }

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ]),
        )
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    private func assertBoundaryMovePreservesBsp(
        _ direction: CardinalDirection,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .bsp
        root.changeOrientation(direction.orientation)

        let nested: TilingContainer
        let movedWindow: TestWindow
        if direction.isPositive {
            nested = TilingContainer(
                parent: root,
                adaptiveWeight: 1,
                direction.orientation.opposite,
                .bsp,
                index: INDEX_BIND_LAST,
            )
            movedWindow = TestWindow.new(id: 1, parent: root)
        } else {
            movedWindow = TestWindow.new(id: 1, parent: root)
            nested = TilingContainer(
                parent: root,
                adaptiveWeight: 1,
                direction.orientation.opposite,
                .bsp,
                index: INDEX_BIND_LAST,
            )
        }
        TestWindow.new(id: 2, parent: nested)
        TestWindow.new(id: 3, parent: nested)
        assertEquals(movedWindow.focusWindow(), true)

        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], direction))
            .run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()

        XCTAssertEqual(result.exitCode, 0, file: file, line: line)
        XCTAssertEqual(workspace.rootTilingContainer.layout, .bsp, file: file, line: line)
        let nestedDescription: LayoutDescription = direction.orientation == .h
            ? .v_tiles([.window(2), .window(3)])
            : .h_tiles([.window(2), .window(3)])
        let expectedChildren: [LayoutDescription] = direction.isPositive
            ? [nestedDescription, .window(1)]
            : [.window(1), nestedDescription]
        let expected: LayoutDescription = direction.orientation == .h
            ? .h_tiles(expectedChildren)
            : .v_tiles(expectedChildren)
        XCTAssertEqual(
            workspace.rootTilingContainer.layoutDescription,
            expected,
            file: file,
            line: line,
        )
        assertBinaryBsp(workspace.rootTilingContainer, file: file, line: line)

        let insertedWindow = TestWindow.new(id: 4, parent: workspace)
        try await insertedWindow.relayoutWindow(on: workspace, forceTile: true)
        workspace.normalizeContainers()

        XCTAssertEqual(workspace.rootTilingContainer.layout, .bsp, file: file, line: line)
        XCTAssertEqual(workspace.rootTilingContainer.children.count, 2, file: file, line: line)
        XCTAssertTrue(insertedWindow.parent is TilingContainer, file: file, line: line)
        assertBinaryBsp(workspace.rootTilingContainer, file: file, line: line)
    }

    private func assertBinaryBsp(
        _ container: TilingContainer,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        XCTAssertEqual(container.layout, .bsp, file: file, line: line)
        XCTAssertEqual(container.children.count, 2, file: file, line: line)
        for child in container.children.compactMap({ $0 as? TilingContainer }) {
            assertBinaryBsp(child, file: file, line: line)
        }
    }
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        return switch nodeCases {
            case .window(let window): .window(window.windowId)
            case .workspace(let workspace): .workspace(workspace.children.map(\.layoutDescription))
            case .macosMinimizedWindowsContainer: .macosMinimized
            case .macosFullscreenWindowsContainer: .macosFullscreen
            case .macosHiddenAppsWindowsContainer: .macosHiddeAppWindow
            case .macosPopupWindowsContainer: .macosPopupWindowsContainer
            case .tilingContainer(let container):
                switch container.layout {
                    case .tiles:
                        container.orientation == .h
                            ? .h_tiles(container.children.map(\.layoutDescription))
                            : .v_tiles(container.children.map(\.layoutDescription))
                    case .accordion:
                        container.orientation == .h
                            ? .h_accordion(container.children.map(\.layoutDescription))
                            : .v_accordion(container.children.map(\.layoutDescription))
                    case .bsp:
                        container.orientation == .h
                            ? .h_tiles(container.children.map(\.layoutDescription))
                            : .v_tiles(container.children.map(\.layoutDescription))
                }
        }
    }
}

enum LayoutDescription: Equatable {
    case workspace([LayoutDescription])
    case h_tiles([LayoutDescription])
    case v_tiles([LayoutDescription])
    case h_accordion([LayoutDescription])
    case v_accordion([LayoutDescription])
    case window(UInt32)
    case macosPopupWindowsContainer
    case macosMinimized
    case macosHiddeAppWindow
    case macosFullscreen
}
