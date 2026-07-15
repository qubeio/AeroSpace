public struct DebugTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState

    public init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }

    public static let parser: CmdParser<Self> = .init(
        kind: .debugTree,
        allowInConfig: false,
        help: debug_tree_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
    )

    public var json: Bool = false
}
