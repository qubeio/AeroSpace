import AppKit

let minimumBspResizeSize: CGFloat = 1

func clampBspResizeDiff(
    _ requestedDiff: CGFloat,
    growingWeights: [CGFloat],
    shrinkingWeights: [CGFloat],
) -> CGFloat {
    guard !growingWeights.isEmpty, !shrinkingWeights.isEmpty else { return 0 }
    let minimumDiff = growingWeights.map { minimumBspResizeSize - $0 }.max() ?? 0
    let maximumDiff = shrinkingWeights
        .map { ($0 - minimumBspResizeSize) * CGFloat(shrinkingWeights.count) }
        .min() ?? 0
    return min(max(requestedDiff, minimumDiff), maximumDiff)
}
