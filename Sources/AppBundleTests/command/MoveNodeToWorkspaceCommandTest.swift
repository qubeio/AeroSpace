@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveNodeToWorkspaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseCommandSucc("move-node-to-workspace next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)))
        assertEquals(parseCommand("move-node-to-workspace --fail-if-noop next").errorOrNil, "--fail-if-noop is incompatible with (next|prev)")
        assertEquals(parseCommand("move-node-to-workspace --stdin foo").errorOrNil, "--stdin and --no-stdin require using (next|prev) argument")
        testParseCommandSucc("move-node-to-workspace --stdin next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.explicitStdinFlag, true))
        testParseCommandSucc("move-node-to-workspace --no-stdin next", MoveNodeToWorkspaceCmdArgs(target: .relative(.next)).copy(\.explicitStdinFlag, false))
    }

    func testSimple() async throws {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals((Workspace.get(byName: "b").rootTilingContainer.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testEmptyWorkspaceSubject() async throws {
        let workspaceA = Workspace.get(byName: "a")
        workspaceA.rootTilingContainer.apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.workspace.name, "a")
    }

    func testAnotherWindowSubject() async throws {
        Workspace.get(byName: "a").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            _ = TestWindow.new(id: 2, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testPreserveFloatingLayout() async throws {
        config.defaultRootContainerLayout = .bsp
        let workspaceA = Workspace.get(byName: "a").apply {
            _ = TestWindow.new(id: 1, parent: $0).focusWindow()
        }

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b")).run(.defaultEnv, .emptyStdin)
        XCTAssertTrue(workspaceA.isEffectivelyEmpty)
        assertEquals(Workspace.get(byName: "b").children.filterIsInstance(of: Window.self).singleOrNil()?.windowId, 1)
    }

    func testBspTargetSplitsTailInsteadOfAppendingThirdRootChild() async throws {
        config.defaultRootContainerLayout = .bsp
        let sourceWorkspace = Workspace.get(byName: "a")
        let targetRoot = Workspace.get(byName: "b").rootTilingContainer
        _ = TestWindow.new(id: 1, parent: sourceWorkspace.rootTilingContainer).focusWindow()
        TestWindow.new(id: 2, parent: targetRoot)
        TestWindow.new(id: 3, parent: targetRoot)

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b"))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(targetRoot.children.count, 2)
        assertEquals((targetRoot.children[0] as? Window)?.windowId, 2)
        let splitContainer = try XCTUnwrap(targetRoot.children[1] as? TilingContainer)
        assertEquals(splitContainer.children.filterIsInstance(of: Window.self).map(\.windowId), [3, 1])
    }

    func testEmptyBspTargetReceivesSoleRootChild() async throws {
        config.defaultRootContainerLayout = .bsp
        let sourceWorkspace = Workspace.get(byName: "a")
        let targetRoot = Workspace.get(byName: "b").rootTilingContainer
        _ = TestWindow.new(id: 1, parent: sourceWorkspace.rootTilingContainer).focusWindow()

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b"))
            .run(.defaultEnv, .emptyStdin)

        assertEquals((targetRoot.children.singleOrNil() as? Window)?.windowId, 1)
    }

    func testTilesTargetPreservesFlatAppend() async throws {
        let sourceWorkspace = Workspace.get(byName: "a")
        let targetRoot = Workspace.get(byName: "b").rootTilingContainer
        _ = TestWindow.new(id: 1, parent: sourceWorkspace.rootTilingContainer).focusWindow()
        TestWindow.new(id: 2, parent: targetRoot)
        TestWindow.new(id: 3, parent: targetRoot)

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "b"))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(targetRoot.children.filterIsInstance(of: Window.self).map(\.windowId), [2, 3, 1])
    }

    func testExplicitIndexPreservesFlatBspInsertion() async throws {
        config.defaultRootContainerLayout = .bsp
        let sourceWorkspace = Workspace.get(byName: "a")
        let targetWorkspace = Workspace.get(byName: "b")
        let targetRoot = targetWorkspace.rootTilingContainer
        let window = TestWindow.new(id: 1, parent: sourceWorkspace.rootTilingContainer)
        TestWindow.new(id: 2, parent: targetRoot)
        TestWindow.new(id: 3, parent: targetRoot)
        let io = CmdIo(stdin: .emptyStdin)

        _ = try await moveWindowToWorkspace(
            window,
            targetWorkspace,
            io,
            focusFollowsWindow: false,
            failIfNoop: false,
            index: 0,
        )

        assertEquals(targetRoot.children.filterIsInstance(of: Window.self).map(\.windowId), [1, 2, 3])
    }

    func testSummonWindow() async throws {
        let workspaceA = Workspace.get(byName: "a").apply {
            $0.rootTilingContainer.apply {
                _ = TestWindow.new(id: 1, parent: $0).focusWindow()
            }
        }
        Workspace.get(byName: "b").rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        assertEquals(focus.workspace, workspaceA)

        try await MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "a").copy(\.windowId, 2))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(focus.workspace, workspaceA)
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(Workspace.get(byName: "b").rootTilingContainer.children.count, 0)
        assertEquals(workspaceA.rootTilingContainer.children.count, 2)
    }
}
