@testable import AppBundle
import Common
import XCTest

@MainActor
final class ResetWorkspaceBspCommandTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.defaultRootContainerLayout = .bsp
    }

    func testParse() {
        testParseCommandSucc("reset-workspace-bsp", ResetWorkspaceBspCmdArgs(rawArgs: []))
        testParseCommandSucc(
            "reset-workspace-bsp --workspace recovery",
            ResetWorkspaceBspCmdArgs(rawArgs: [])
                .copy(\.workspaceName, WorkspaceName.parse("recovery").getOrDie()),
        )
    }

    func testRebuildsFlatTilesAsBinaryBsp() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        root.layout = .tiles
        for id: UInt32 in 1 ... 4 {
            TestWindow.new(id: id, parent: root)
        }
        assertEquals(workspace.focusWorkspace(), true)

        let result = try await ResetWorkspaceBspCommand(args: ResetWorkspaceBspCmdArgs(rawArgs: []))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(workspace.rootTilingContainer.layout, .bsp)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(3), .window(4)]),
                ]),
            ]),
        )
        assertBinaryBsp(workspace.rootTilingContainer)
    }

    func testPreservesFloatingWindows() async throws {
        let workspace = Workspace.get(byName: name)
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace)
        assertEquals(workspace.focusWorkspace(), true)

        _ = try await ResetWorkspaceBspCommand(args: ResetWorkspaceBspCmdArgs(rawArgs: []))
            .run(.defaultEnv, .emptyStdin)

        XCTAssertTrue(tiled.parent is TilingContainer)
        XCTAssertTrue(floating.parent === workspace)
    }

    func testRejectsTilesLayout() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertEquals(window.focusWindow(), true)

        let result = try await LayoutCommand(
            args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles]),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        assertEquals(
            result.stderr,
            ["Layout 'tiles' is unavailable: this build supports BSP tiling only"],
        )
        assertEquals(workspace.rootTilingContainer.layout, .bsp)
    }

    private func assertBinaryBsp(_ container: TilingContainer, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(container.children.count, 2, file: file, line: line)
        for child in container.children.compactMap({ $0 as? TilingContainer }) {
            XCTAssertEqual(child.layout, .bsp, file: file, line: line)
            assertBinaryBsp(child, file: file, line: line)
        }
    }
}
