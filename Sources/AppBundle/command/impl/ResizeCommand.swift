import AppKit
import Common

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }

        let candidates = target.windowOrNil?.parentsWithSelf
            .filter { if let p = $0.parent as? TilingContainer { p.layout == .tiles || p.layout == .bsp } else { false } }
            ?? []

        let orientation: Orientation?
        let parent: TilingContainer?
        let node: TreeNode?
        switch args.dimension.val {
            case .width:
                orientation = .h
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .height:
                orientation = .v
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .smart:
                node = candidates.first
                parent = node?.parent as? TilingContainer
                orientation = parent?.orientation
            case .smartOpposite:
                orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
        }
        guard let parent else { return io.err("resize command doesn't support floating windows yet https://github.com/nikitabobko/AeroSpace/issues/9") }
        guard let orientation else { return false }
        guard let node else { return false }
        guard parent.children.count > 1 else { return false }
        if parent.layout == .bsp {
            normalizeBspWeightsToPixels(parent, workspace: target.workspace)
        }

        let requestedDiff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - node.getWeight(orientation)
            case .add(let unit): CGFloat(unit)
            case .subtract(let unit): -CGFloat(unit)
        }

        let diff: CGFloat = if parent.layout == .bsp {
            clampBspResizeDiff(
                requestedDiff,
                growingWeights: [node.getWeight(orientation)],
                shrinkingWeights: parent.children.filter { $0 != node }.map { $0.getWeight(orientation) },
            )
        } else {
            requestedDiff
        }
        guard let childDiff = diff.div(parent.children.count - 1) else { return false }
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        return true
    }
}

@MainActor
private func normalizeBspWeightsToPixels(_ parent: TilingContainer, workspace: Workspace) {
    let orientation = parent.orientation
    let parentSize = computeVirtualSlotRect(of: parent, workspace: workspace).getDimension(orientation)
    guard parentSize.isFinite, parentSize > 0, !parent.children.isEmpty else { return }

    let weights = parent.children.map { $0.getWeight(orientation) }
    let totalWeight = weights.reduce(0, +)
    let pixelWeights: [CGFloat] = if totalWeight.isFinite, totalWeight > 0, weights.allSatisfy({ $0.isFinite && $0 > 0 }) {
        weights.map { parentSize * $0 / totalWeight }
    } else {
        Array(repeating: parentSize / CGFloat(parent.children.count), count: parent.children.count)
    }
    for (child, pixelWeight) in zip(parent.children, pixelWeights) {
        child.setWeight(orientation, pixelWeight)
    }
}
