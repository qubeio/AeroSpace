import AppKit
import Common

struct ResetWorkspaceBspCommand: Command {
    let args: ResetWorkspaceBspCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let workspace = target.workspace
        let windows = workspace.rootTilingContainer.allLeafWindowsRecursive

        for window in windows {
            window.bind(to: NilTreeNode.instance, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
        workspace.normalizeContainers()

        let root = workspace.rootTilingContainer
        root.layout = .bsp
        for window in windows {
            window.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            try await window.relayoutWindow(on: workspace, forceTile: true)
        }
        workspace.normalizeContainers()

        bspLog.info(
            "reset-workspace-bsp workspace=\(workspace.name, privacy: .public) windows=\(windows.count, privacy: .public)",
        )
        return true
    }
}
