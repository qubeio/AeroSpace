@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class DebugTreeCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.defaultRootContainerLayout = .bsp
    }

    func testParse() {
        testParseCommandSucc("debug-tree", DebugTreeCmdArgs(rawArgs: []))
        testParseCommandSucc(
            "debug-tree --workspace diagnostics --json",
            DebugTreeCmdArgs(rawArgs: [])
                .copy(\.workspaceName, WorkspaceName.parse("diagnostics").getOrDie())
                .copy(\.json, true),
        )
        assertEquals(
            parseCommand("debug-tree --workspace").errorOrNil,
            "ERROR: '--workspace' must be followed by mandatory workspace name",
        )
    }

    func testTextOutputShowsBspNestingAndMarkers() async throws {
        let workspace = Workspace.get(byName: "diagnostics")
        let root = workspace.rootTilingContainer
        _ = TestWindow.new(id: 1, parent: root, adaptiveWeight: 2)
        let nested = TilingContainer(parent: root, adaptiveWeight: 1, .v, .bsp, index: INDEX_BIND_LAST)
        let focused = TestWindow.new(id: 2, parent: nested)
        let mru = TestWindow.new(id: 3, parent: nested)
        focused.lastAppliedLayoutVirtualRect = Rect(topLeftX: 0, topLeftY: 0, width: 960, height: 540)
        assertEquals(focused.focusWindow(), true)
        mru.markAsMostRecentChild()

        let result = try await command(workspace: workspace.name).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(result.stderr, [])
        let output = result.stdout.singleOrNil().orDie()
        XCTAssertTrue(output.contains("Workspace diagnostics"))
        XCTAssertTrue(output.contains("container h bsp"))
        XCTAssertTrue(output.contains("container v bsp"))
        XCTAssertTrue(output.contains("window 2 bobko.AeroSpace.test-app \"TestWindow(2)\""))
        XCTAssertTrue(output.contains("window 2") && output.contains("[focused]"))
        XCTAssertTrue(output.contains("window 3") && output.contains("[mru]"))
        XCTAssertTrue(output.contains("cached=(0.0,0.0 960.0x540.0)"))
        XCTAssertTrue(output.contains("computed="))
    }

    func testJsonOutputContainsNestedStructure() async throws {
        let workspace = Workspace.get(byName: "json")
        let root = workspace.rootTilingContainer
        _ = TestWindow.new(id: 1, parent: root, adaptiveWeight: 2)
        let nested = TilingContainer(parent: root, adaptiveWeight: 1, .v, .bsp, index: INDEX_BIND_LAST)
        _ = TestWindow.new(id: 2, parent: nested)

        let result = try await command(workspace: workspace.name, json: true).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        let data = result.stdout.singleOrNil().orDie().data(using: .utf8).orDie()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        assertEquals(json?["kind"] as? String, "workspace")
        assertEquals(json?["rootLayout"] as? String, "bsp")
        let rootJson = (json?["children"] as? [[String: Any]])?.singleOrNil()
        assertEquals(rootJson?["kind"] as? String, "tiling-container")
        assertEquals(rootJson?["orientation"] as? String, "h")
        XCTAssertNotNil(rootJson?["adaptiveWeight"])
        let rootChildren = rootJson?["children"] as? [[String: Any]]
        assertEquals(rootChildren?.count, 2)
        let nestedJson = rootChildren?[1]
        assertEquals(nestedJson?["layout"] as? String, "bsp")
        assertEquals(nestedJson?["orientation"] as? String, "v")
    }

    func testUnknownWorkspaceFailsWithoutCreatingIt() async throws {
        let countBefore = Workspace.all.count
        let result = try await command(workspace: "does-not-exist").run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        assertEquals(result.stderr, ["Workspace 'does-not-exist' doesn't exist"])
        assertEquals(Workspace.all.count, countBefore)
    }

    func testEmptyWorkspaceDoesNotCreateRootContainer() async throws {
        let workspace = Workspace.get(byName: "empty")
        assertEquals(workspace.children.count, 0)

        let result = try await command(workspace: workspace.name).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(result.stdout.singleOrNil()?.contains("root-layout=bsp (default) (empty)") == true)
        assertEquals(workspace.children.count, 0)
    }

    private func command(workspace: String, json: Bool = false) -> DebugTreeCommand {
        DebugTreeCommand(
            args: DebugTreeCmdArgs(rawArgs: [])
                .copy(\.workspaceName, WorkspaceName.parse(workspace).getOrDie())
                .copy(\.json, json),
        )
    }
}
