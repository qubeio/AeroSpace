@testable import AppBundle
import Common
import XCTest

@MainActor
final class FullscreenCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.defaultRootContainerLayout = .bsp
    }

    func testFocusChangeKeepsFullscreenWindowFullscreen() async throws {
        let workspace = Workspace.get(byName: name)
        let windows = try await insertSpiralWindows(1 ... 2, into: workspace)

        _ = try await parseCommand("fullscreen on --window-id 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await workspace.layoutWorkspace()
        windows[1].markAsMostRecentChild()
        try await workspace.layoutWorkspace()

        XCTAssertTrue(windows[0].isFullscreen)
        XCTAssertTrue(workspace.mostRecentWindowRecursive === windows[1])
        assertFullscreenFrame(windows[0], in: workspace)
    }

    func testSpawnWhileFullscreenPreservesBspAndRestoresUnderlyingLayout() async throws {
        let workspace = Workspace.get(byName: name)
        let windows = try await insertSpiralWindows(1 ... 4, into: workspace)
        let fullscreenWindow = windows[1]
        _ = try await parseCommand("fullscreen on --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await workspace.layoutWorkspace()

        let newWindow = TestWindow.new(id: 5, parent: workspace)
        try await newWindow.relayoutWindow(on: workspace, forceTile: true)
        try await workspace.layoutWorkspace()

        let expectedTree: LayoutDescription = .h_tiles([
            .window(1),
            .v_tiles([
                .window(2),
                .h_tiles([
                    .window(3),
                    .v_tiles([.window(4), .window(5)]),
                ]),
            ]),
        ])
        assertEquals(expectedTree, workspace.rootTilingContainer.layoutDescription)
        XCTAssertTrue(fullscreenWindow.isFullscreen)
        XCTAssertTrue(workspace.mostRecentWindowRecursive === newWindow)
        assertFullscreenFrame(fullscreenWindow, in: workspace)

        _ = try await parseCommand("fullscreen off --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await workspace.layoutWorkspace()

        XCTAssertFalse(fullscreenWindow.isFullscreen)
        assertEquals(expectedTree, workspace.rootTilingContainer.layoutDescription)
        XCTAssertEqual(fullscreenWindow.rect?.topLeftX, fullscreenWindow.lastAppliedLayoutPhysicalRect?.topLeftX)
        XCTAssertEqual(fullscreenWindow.rect?.topLeftY, fullscreenWindow.lastAppliedLayoutPhysicalRect?.topLeftY)
        XCTAssertEqual(fullscreenWindow.rect?.width, fullscreenWindow.lastAppliedLayoutPhysicalRect?.width)
        XCTAssertEqual(fullscreenWindow.rect?.height, fullscreenWindow.lastAppliedLayoutPhysicalRect?.height)
    }

    func testEnteringFullscreenTransfersOwnershipWithinWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        let windows = try await insertSpiralWindows(1 ... 2, into: workspace)
        let otherWorkspace = Workspace.get(byName: "other-workspace")
        let otherWindow = TestWindow.new(id: 3, parent: otherWorkspace.rootTilingContainer)

        _ = try await parseCommand("fullscreen on --window-id 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        _ = try await parseCommand("fullscreen on --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        _ = try await parseCommand("fullscreen on --window-id 3").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertFalse(windows[0].isFullscreen)
        XCTAssertTrue(windows[1].isFullscreen)
        XCTAssertTrue(otherWindow.isFullscreen)
    }

    func testClosingFullscreenWindowNormalizesSurvivorTopology() async throws {
        let workspace = Workspace.get(byName: name)
        _ = try await insertSpiralWindows(1 ... 4, into: workspace)
        _ = try await parseCommand("fullscreen on --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)

        _ = try await parseCommand("close --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        workspace.normalizeContainers()

        assertEquals(
            .h_tiles([
                .window(1),
                .h_tiles([.window(3), .window(4)]),
            ]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    private func insertSpiralWindows(_ ids: ClosedRange<UInt32>, into workspace: Workspace) async throws -> [TestWindow] {
        var windows: [TestWindow] = []
        for id in ids {
            let window = TestWindow.new(id: id, parent: workspace)
            try await window.relayoutWindow(on: workspace, forceTile: true)
            windows.append(window)
        }
        return windows
    }

    private func assertFullscreenFrame(_ window: TestWindow, in workspace: Workspace) {
        let expected = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        XCTAssertEqual(window.rect?.topLeftX, expected.topLeftX)
        XCTAssertEqual(window.rect?.topLeftY, expected.topLeftY)
        XCTAssertEqual(window.rect?.width, expected.width)
        XCTAssertEqual(window.rect?.height, expected.height)
    }
}
