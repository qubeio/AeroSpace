@testable import AppBundle
import XCTest

@MainActor
final class BSPSplitOrientationTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.defaultRootContainerLayout = .bsp
    }

    /// Regression test: previously, deciding orientation from `lastAppliedLayoutVirtualRect` (nil until a layout
    /// pass runs) caused two windows arriving in the same refresh to stack top/bottom on a landscape monitor.
    func testTwoWindows_noLayoutPassBetween_splitSideBySide() async throws {
        let workspace = Workspace.get(byName: name)
        let window1 = TestWindow.new(id: 1, parent: workspace)
        let window2 = TestWindow.new(id: 2, parent: workspace)

        try await window1.relayoutWindow(on: workspace, forceTile: true)
        XCTAssertNil(window1.lastAppliedLayoutVirtualRect)
        try await window2.relayoutWindow(on: workspace, forceTile: true)
        XCTAssertNil(window2.lastAppliedLayoutVirtualRect)

        assertEquals(
            .h_tiles([.h_tiles([.window(1), .window(2)])]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    /// 4-window sequential insertion produces the classic fibonacci/BSP spiral structure.
    func testFourWindows_producesSpiralStructure() async throws {
        let workspace = Workspace.get(byName: name)
        for id: UInt32 in 1 ... 4 {
            let window = TestWindow.new(id: id, parent: workspace)
            try await window.relayoutWindow(on: workspace, forceTile: true)
        }

        assertEquals(
            .h_tiles([.h_tiles([
                .window(1),
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(3), .window(4)]),
                ]),
            ])]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    func testPreferredSplitDirectionOverride_ignoresGeometry() async throws {
        config.bsp.preferredSplitDirection = .v
        let workspace = Workspace.get(byName: name)
        let window1 = TestWindow.new(id: 1, parent: workspace)
        let window2 = TestWindow.new(id: 2, parent: workspace)
        try await window1.relayoutWindow(on: workspace, forceTile: true)
        try await window2.relayoutWindow(on: workspace, forceTile: true)

        assertEquals(
            .h_tiles([.v_tiles([.window(1), .window(2)])]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    func testComputeVirtualSlotRect_reflectsUnequalWeights() {
        let workspace = Workspace.get(byName: name)
        let window1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer, adaptiveWeight: 3)
        let window2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer, adaptiveWeight: 1)

        let rect1 = computeVirtualSlotRect(of: window1, workspace: workspace)
        let rect2 = computeVirtualSlotRect(of: window2, workspace: workspace)
        let monitorRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps

        XCTAssertEqual(rect1.width / monitorRect.width, 0.75, accuracy: 0.0001)
        XCTAssertEqual(rect2.width / monitorRect.width, 0.25, accuracy: 0.0001)
        XCTAssertEqual(rect1.height, monitorRect.height, accuracy: 0.0001)
    }

    func testComputeVirtualSlotRect_accordionChildPassesThroughFullRect() {
        let workspace = Workspace.get(byName: name)
        let accordion = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .h, .accordion, index: INDEX_BIND_LAST)
        let window1 = TestWindow.new(id: 1, parent: accordion)
        _ = TestWindow.new(id: 2, parent: accordion)

        let rect = computeVirtualSlotRect(of: window1, workspace: workspace)
        let monitorRect = workspace.workspaceMonitor.visibleRectPaddedByOuterGaps

        XCTAssertEqual(rect.width, monitorRect.width, accuracy: 0.0001)
        XCTAssertEqual(rect.height, monitorRect.height, accuracy: 0.0001)
    }
}
