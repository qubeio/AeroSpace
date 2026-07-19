public struct ResetWorkspaceBspCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState

    public init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }

    public static let parser: CmdParser<Self> = .init(
        kind: .resetWorkspaceBsp,
        allowInConfig: true,
        help: reset_workspace_bsp_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )
}
