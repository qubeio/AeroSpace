extension Workspace {
    @MainActor func normalizeContainers() {
        var didPromoteToRoot = false
        rootTilingContainer.unbindEmptyAndAutoFlatten(didPromoteToRoot: &didPromoteToRoot) // Beware! rootTilingContainer may change after this line of code
        if config.enableNormalizationOppositeOrientationForNestedContainers {
            rootTilingContainer.normalizeOppositeOrientationForNestedContainers()
        }
        if didPromoteToRoot {
            reorientBspRootAfterPromotionIfNeeded()
        }
    }

    /// After a nested BSP container is promoted to the workspace root, recompute its orientation from
    /// full workspace geometry (policy A: preferred-split-direction → slot ratio / threshold).
    @MainActor
    private func reorientBspRootAfterPromotionIfNeeded() {
        let root = rootTilingContainer
        guard root.layout == .bsp else { return }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        let target = bspOrientation(for: rect, workspace: self)
        let old = root.orientation
        guard old != target else { return }
        root.changeOrientation(target)
        let windowCount = root.allLeafWindowsRecursive.count
        let oldDesc = old == .h ? "h" : "v"
        let newDesc = target == .h ? "h" : "v"
        bspLog.info(
            "root-promote-reorient workspace=\(self.name, privacy: .public) old=\(oldDesc, privacy: .public) new=\(newDesc, privacy: .public) windows=\(windowCount, privacy: .public)",
        )
    }
}

extension TilingContainer {
    @MainActor fileprivate func unbindEmptyAndAutoFlatten(didPromoteToRoot: inout Bool) {
        if let child = children.singleOrNil(),
           (config.enableNormalizationFlattenContainers || layout == .bsp)
           && (child is TilingContainer || !isRootContainer)
        {
            child.unbindFromParent()
            let mru = parent?.mostRecentChild
            let previousBinding = unbindFromParent()
            child.bind(to: previousBinding.parent, adaptiveWeight: previousBinding.adaptiveWeight, index: previousBinding.index)
            if previousBinding.parent is Workspace {
                didPromoteToRoot = true
            }
            (child as? TilingContainer)?.unbindEmptyAndAutoFlatten(didPromoteToRoot: &didPromoteToRoot)
            if mru != self {
                mru?.markAsMostRecentChild()
            } else {
                child.markAsMostRecentChild()
            }
        } else {
            for child in children {
                (child as? TilingContainer)?.unbindEmptyAndAutoFlatten(didPromoteToRoot: &didPromoteToRoot)
            }
            if children.isEmpty && !isRootContainer {
                unbindFromParent()
            }
        }
    }
}
