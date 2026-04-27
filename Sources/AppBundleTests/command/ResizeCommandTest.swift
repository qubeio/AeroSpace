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
    func testBspResizeWidthAdd() async throws {
        // Horizontal BSP container with 3 equal-weight windows
        config.defaultRootContainerLayout = .bsp
        let root = Workspace.get(byName: name).rootTilingContainer // .bsp, .h
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)
        let w3 = TestWindow.new(id: 3, parent: root, adaptiveWeight: 1)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(1)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(w1.getWeight(.h), 2.0)  // 1 + 1
        assertEquals(w2.getWeight(.h), 0.5)  // 1 - 0.5
        assertEquals(w3.getWeight(.h), 0.5)  // 1 - 0.5
    }

    @MainActor
    func testBspResizeWidthSubtract() async throws {
        config.defaultRootContainerLayout = .bsp
        let root = Workspace.get(byName: name).rootTilingContainer // .bsp, .h
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 2)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 2)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .subtract(1)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(w1.getWeight(.h), 1.0)  // 2 - 1
        assertEquals(w2.getWeight(.h), 3.0)  // 2 + 1
    }

    @MainActor
    func testBspResizeHeightAdd() async throws {
        // Vertical BSP container with 2 equal-weight windows
        config.defaultRootContainerLayout = .bsp
        config.defaultRootContainerOrientation = .vertical
        let root = Workspace.get(byName: name).rootTilingContainer // .bsp, .v
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(1)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(w1.getWeight(.v), 2.0)  // 1 + 1
        assertEquals(w2.getWeight(.v), 0.0)  // 1 - 1
    }

    @MainActor
    func testBspResizeSingleChildIsNoOp() async throws {
        // Resizing the only child in a BSP container should return false (not crash)
        config.defaultRootContainerLayout = .bsp
        let root = Workspace.get(byName: name).rootTilingContainer
        let w1 = TestWindow.new(id: 1, parent: root)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 1) // div(0) returns nil → no-op, returns false → exitCode 1
        assertEquals(w1.getWeight(.h), 1.0) // weight unchanged
    }

    @MainActor
    func testBspResizeSmartPicksFirstCandidate() async throws {
        // Smart resize: picks first candidate — the direct parent (BSP horizontal)
        config.defaultRootContainerLayout = .bsp
        let root = Workspace.get(byName: name).rootTilingContainer // .bsp, .h
        let w1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(1)))
            .run(.defaultEnv.copy(\.windowId, w1.windowId), .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(w1.getWeight(.h), 2.0)  // 1 + 1
        assertEquals(w2.getWeight(.h), 0.0)  // 1 - 1
    }

    @MainActor
    func testBspResizeSiblingWeightsTotalUnchanged() async throws {
        // After resize, total weight should be preserved (weight conservation)
        config.defaultRootContainerLayout = .bsp
        let root = Workspace.get(byName: name).rootTilingContainer // .bsp, .h
        _ = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let w2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 1)
        _ = TestWindow.new(id: 3, parent: root, adaptiveWeight: 1)
        let totalBefore = root.children.reduce(0.0) { $0 + $1.getWeight(.h) }

        _ = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(1)))
            .run(.defaultEnv.copy(\.windowId, w2.windowId), .emptyStdin)

        let totalAfter = root.children.reduce(0.0) { $0 + $1.getWeight(.h) }
        assertEquals(totalBefore, totalAfter)
    }
}
