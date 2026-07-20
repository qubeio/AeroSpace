@testable import AppBundle
import Common
import XCTest

@MainActor
final class ResizeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseCommand() {
        testParseCommandSucc("resize smart +10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(10)))
        testParseCommandSucc("resize smart -10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtract(10)))
        testParseCommandSucc("resize smart 10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .set(10)))

        testParseCommandSucc("resize smart-opposite +10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(10)))
        testParseCommandSucc("resize smart-opposite -10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .subtract(10)))
        testParseCommandSucc("resize smart-opposite 10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .set(10)))

        testParseCommandSucc("resize height 10", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .set(10)))
        testParseCommandSucc("resize width 10", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(10)))

        testParseCommandFail("resize s 10", msg: """
            ERROR: Can't parse 's'.
                   Possible values: (width|height|smart|smart-opposite)
            """)
        testParseCommandFail("resize smart foo", msg: "ERROR: <number> argument must be a number")
    }

    // MARK: - BSP resize functional tests

    @MainActor
    func testBspResizeSmartAddUsesPixels() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(computeVirtualSlotRect(of: w1, workspace: workspace).width, 1010, accuracy: 0.001)
        assertEquals(computeVirtualSlotRect(of: w2, workspace: workspace).width, 910)
    }

    @MainActor
    func testBspResizeSmartSubtractUsesPixels() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtract(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(computeVirtualSlotRect(of: w1, workspace: workspace).width, 910)
        XCTAssertEqual(computeVirtualSlotRect(of: w2, workspace: workspace).width, 1010, accuracy: 0.001)
    }

    @MainActor
    func testBspResizeVerticalUsesPixels() async throws {
        config.defaultRootContainerLayout = .bsp
        config.defaultRootContainerOrientation = .vertical
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(computeVirtualSlotRect(of: w1, workspace: workspace).height, 590)
        assertEquals(computeVirtualSlotRect(of: w2, workspace: workspace).height, 490)
    }

    @MainActor
    func testBspResizeThreeChildrenDistributesPixelDelta() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root)
        let w2 = TestWindow.new(id: 2, parent: root)
        let w3 = TestWindow.new(id: 3, parent: root)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(computeVirtualSlotRect(of: w1, workspace: workspace).width, 690)
        assertEquals(computeVirtualSlotRect(of: w2, workspace: workspace).width, 615)
        assertEquals(computeVirtualSlotRect(of: w3, workspace: workspace).width, 615)
    }

    @MainActor
    func testBspResizeClampsAtOnePixel() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        for _ in 0 ..< 100 {
            _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
                .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)
        }

        assertEquals(w1.getWeight(.h), 1919)
        assertEquals(w2.getWeight(.h), 1)
        XCTAssertGreaterThan(w1.getWeight(.h), 0)
        XCTAssertGreaterThan(w2.getWeight(.h), 0)
    }

    @MainActor
    func testBspResizeFocusedSecondSibling() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w2.windowId), .emptyStdin)

        assertEquals(computeVirtualSlotRect(of: w1, workspace: workspace).width, 910)
        XCTAssertEqual(computeVirtualSlotRect(of: w2, workspace: workspace).width, 1010, accuracy: 0.001)
    }

    @MainActor
    func testBspResizeNestedContainerTargetsDirectSplit() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let nested = TilingContainer(parent: root, adaptiveWeight: 1, .v, .bsp, index: INDEX_BIND_LAST)
        let outside = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 2, parent: nested, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 3, parent: nested, adaptiveWeight: 1)

        _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(computeVirtualSlotRect(of: nested, workspace: workspace).width, 960)
        assertEquals(computeVirtualSlotRect(of: outside, workspace: workspace).width, 960)
        assertEquals(computeVirtualSlotRect(of: w1, workspace: workspace).height, 590)
        assertEquals(computeVirtualSlotRect(of: w2, workspace: workspace).height, 490)
    }

    @MainActor
    func testBspResizeRepairsInvalidWeights() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: -49)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 51)

        _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        XCTAssertEqual(computeVirtualSlotRect(of: w1, workspace: workspace).width, 1010, accuracy: 0.001)
        assertEquals(computeVirtualSlotRect(of: w2, workspace: workspace).width, 910)
    }

    func testBspResizeClampProtectsEveryMouseAffectedNode() {
        assertEquals(
            clampBspResizeDiff(50, growingWeights: [100, 50], shrinkingWeights: [10, 20]),
            18,
        )
        assertEquals(
            clampBspResizeDiff(-100, growingWeights: [100, 50], shrinkingWeights: [10, 20]),
            -49,
        )
    }

    @MainActor
    func testBspResizeAbsoluteValueUsesPixels() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(500)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        XCTAssertEqual(computeVirtualSlotRect(of: w1, workspace: workspace).width, 500, accuracy: 0.001)
        assertEquals(computeVirtualSlotRect(of: w2, workspace: workspace).width, 1420)
    }

    @MainActor
    func testBspResizeSingleChildIsNoOp() async throws {
        config.defaultRootContainerLayout = .bsp
        let root = Workspace.get(byName: name).rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 1)
        assertEquals(w1.getWeight(.h), 1)
    }

    @MainActor
    func testTilesResizeBehaviorIsUnchanged() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        root.layout = .tiles
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 100)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 100)

        _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(50)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(w1.getWeight(.h), 150)
        assertEquals(w2.getWeight(.h), 50)
    }
}
