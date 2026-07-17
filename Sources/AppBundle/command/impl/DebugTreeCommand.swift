import AppKit
import Common
import Foundation

struct DebugTreeCommand: Command {
    let args: DebugTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let workspace: Workspace
        if let workspaceName = args.workspaceName?.raw ?? env.workspaceName {
            guard let existing = Workspace.all.first(where: { $0.name == workspaceName }) else {
                return io.err("Workspace '\(workspaceName)' doesn't exist")
            }
            workspace = existing
        } else {
            workspace = focus.workspace
        }

        let snapshot = try await DebugTreeSnapshot.capture(workspace: workspace, focusedWindow: focus.windowOrNil)
        if args.json {
            return JSONEncoder.aeroSpaceDefault.encodeToString(snapshot).map(io.out)
                ?? io.err("Failed to encode debug tree as JSON")
        } else {
            return io.out(snapshot.textDescription)
        }
    }
}

private struct DebugTreeSnapshot: Encodable {
    let kind: String
    let name: String
    let monitor: String
    let monitorRect: DebugTreeRect
    let rootLayout: String
    let rootLayoutIsDefault: Bool
    let children: [DebugTreeNode]

    @MainActor
    static func capture(workspace: Workspace, focusedWindow: Window?) async throws -> DebugTreeSnapshot {
        let root = workspace.children.compactMap { $0 as? TilingContainer }.singleOrNil()
        var children: [DebugTreeNode] = []
        for child in workspace.children {
            children.append(try await .capture(node: child, workspace: workspace, focusedWindow: focusedWindow))
        }
        let monitor = workspace.workspaceMonitor
        return DebugTreeSnapshot(
            kind: "workspace",
            name: workspace.name,
            monitor: sanitizeDebugTreeText(monitor.name, limit: nil),
            monitorRect: DebugTreeRect(monitor.rect),
            rootLayout: (root?.layout ?? config.defaultRootContainerLayout).rawValue,
            rootLayoutIsDefault: root == nil,
            children: children,
        )
    }

    var textDescription: String {
        let defaultMarker = rootLayoutIsDefault ? " (default)" : ""
        let emptyMarker = children.isEmpty ? " (empty)" : ""
        let kindLabel = kind == "workspace" ? "Workspace" : kind
        var lines = [
            "\(kindLabel) \(name)  monitor=\(monitor) \(formatScalar(monitorRect.width))x\(formatScalar(monitorRect.height)) " +
                "root-layout=\(rootLayout)\(defaultMarker)\(emptyMarker)",
        ]
        for (index, child) in children.enumerated() {
            child.appendTextLines(to: &lines, prefix: "", isLast: index == children.count - 1)
        }
        return lines.joined(separator: "\n")
    }
}

private struct DebugTreeNode: Encodable {
    let kind: String
    let layout: String?
    let orientation: String?
    let adaptiveWeight: CGFloat
    let cachedRect: DebugTreeRect?
    let computedRect: DebugTreeRect
    let windowId: UInt32?
    let appName: String?
    let title: String?
    let focused: Bool?
    let mru: Bool?
    let children: [DebugTreeNode]?

    @MainActor
    static func capture(node: TreeNode, workspace: Workspace, focusedWindow: Window?) async throws -> DebugTreeNode {
        var children: [DebugTreeNode] = []
        for child in node.children {
            children.append(try await .capture(node: child, workspace: workspace, focusedWindow: focusedWindow))
        }

        let kind: String
        let layout: String?
        let orientation: String?
        var windowId: UInt32?
        var appName: String?
        var title: String?

        switch node.nodeCases {
            case .window(let window):
                kind = "window"
                layout = nil
                orientation = nil
                windowId = window.windowId
                appName = sanitizeDebugTreeText(window.app.name ?? "unknown", limit: nil)
                title = sanitizeDebugTreeText(try await window.title, limit: 40)
            case .tilingContainer(let container):
                kind = "tiling-container"
                layout = container.layout.rawValue
                orientation = String(describing: container.orientation)
            case .workspace:
                kind = "workspace"
                layout = nil
                orientation = nil
            case .macosMinimizedWindowsContainer:
                kind = "macos-minimized-container"
                layout = nil
                orientation = nil
            case .macosHiddenAppsWindowsContainer:
                kind = "macos-hidden-apps-container"
                layout = nil
                orientation = nil
            case .macosFullscreenWindowsContainer:
                kind = "macos-fullscreen-container"
                layout = nil
                orientation = nil
            case .macosPopupWindowsContainer:
                kind = "macos-popup-container"
                layout = nil
                orientation = nil
        }

        return DebugTreeNode(
            kind: kind,
            layout: layout,
            orientation: orientation,
            adaptiveWeight: node.rawAdaptiveWeight,
            cachedRect: node.lastAppliedLayoutVirtualRect.map(DebugTreeRect.init),
            computedRect: DebugTreeRect(computeVirtualSlotRect(of: node, workspace: workspace)),
            windowId: windowId,
            appName: appName,
            title: title,
            focused: (node === focusedWindow) ? true : nil,
            mru: (node.parent?.mostRecentChild === node) ? true : nil,
            children: children.isEmpty ? nil : children,
        )
    }

    func appendTextLines(to lines: inout [String], prefix: String, isLast: Bool) {
        let connector = isLast ? "└─ " : "├─ "
        var details: String
        switch kind {
            case "tiling-container": details = "container \(orientation ?? "?") \(layout ?? "?")"
            case "window":
                let escapedTitle = (title ?? "").replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                details = "window \(windowId?.description ?? "?") \(appName ?? "unknown") \"\(escapedTitle)\""
            default: details = kind
        }
        details += " w=\(formatScalar(adaptiveWeight))"
        details += " cached=\(cachedRect.map(formatRect) ?? "nil")"
        details += " computed=\(formatRect(computedRect))"
        if mru == true { details += " [mru]" }
        if focused == true { details += " [focused]" }
        lines.append(prefix + connector + details)

        let childPrefix = prefix + (isLast ? "   " : "│  ")
        for (index, child) in (children ?? []).enumerated() {
            child.appendTextLines(to: &lines, prefix: childPrefix, isLast: index == (children?.count ?? 0) - 1)
        }
    }
}

private struct DebugTreeRect: Encodable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(_ rect: Rect) {
        x = rect.topLeftX
        y = rect.topLeftY
        width = rect.width
        height = rect.height
    }
}

private func sanitizeDebugTreeText(_ text: String, limit: Int?) -> String {
    let withoutControls = text.unicodeScalars.map {
        CharacterSet.controlCharacters.contains($0) ? " " : String($0)
    }.joined()
    let normalized = withoutControls.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    guard let limit, normalized.count > limit else { return normalized }
    return String(normalized.prefix(max(0, limit - 3))) + "..."
}

private func formatRect(_ rect: DebugTreeRect) -> String {
    "(\(formatScalar(rect.x)),\(formatScalar(rect.y)) \(formatScalar(rect.width))x\(formatScalar(rect.height)))"
}

private func formatScalar(_ value: CGFloat) -> String {
    guard value.isFinite else { return String(describing: value) }
    var result = String(format: "%.3f", Double(value))
    while result.last == "0" { result.removeLast() }
    if result.last == "." { result.append("0") }
    return result
}
