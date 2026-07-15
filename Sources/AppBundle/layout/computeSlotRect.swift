import Common

/// Rect the node would occupy if the workspace were laid out right now, as if inner gaps were
/// zero (mirrors ``TreeNode/lastAppliedLayoutVirtualRect`` semantics). Unlike that cache, this is
/// computed on demand from the current tree shape, so it doesn't depend on a layout pass having
/// run, and works for nodes in invisible workspaces.
@MainActor
func computeVirtualSlotRect(of node: TreeNode, workspace: Workspace) -> Rect {
    var rect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
    var passedRoot = false
    for n in node.parentsWithSelf.reversed() {
        if !passedRoot {
            if n === workspace.rootTilingContainer { passedRoot = true }
            continue
        }
        guard let container = n.parent as? TilingContainer else { continue }
        switch container.layout {
            case .tiles, .bsp:
                let totalWeight = container.children.sumOfDouble { $0.getWeight(container.orientation) }
                guard totalWeight > 0, let ownIndex = n.ownIndex else { continue }
                let weightBefore = container.children.prefix(ownIndex).sumOfDouble { $0.getWeight(container.orientation) }
                let ownWeight = n.getWeight(container.orientation)
                let offsetFraction = weightBefore / totalWeight
                let sizeFraction = ownWeight / totalWeight
                switch container.orientation {
                    case .h:
                        rect = Rect(
                            topLeftX: rect.topLeftX + rect.width * offsetFraction,
                            topLeftY: rect.topLeftY,
                            width: rect.width * sizeFraction,
                            height: rect.height,
                        )
                    case .v:
                        rect = Rect(
                            topLeftX: rect.topLeftX,
                            topLeftY: rect.topLeftY + rect.height * offsetFraction,
                            width: rect.width,
                            height: rect.height * sizeFraction,
                        )
                }
            case .accordion:
                break // Child inherits the full rect, same as layoutAccordion
        }
    }
    return rect
}
