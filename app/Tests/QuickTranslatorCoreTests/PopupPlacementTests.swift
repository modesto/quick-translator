import CoreGraphics
import Testing
@testable import QuickTranslatorCore

@Suite("PopupPlacement")
struct PopupPlacementTests {
    static let laptop = ScreenArea(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
    )
    static let rightMonitor = ScreenArea(
        frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1440, y: 0, width: 2560, height: 1415)
    )
    static let popup = CGSize(width: 440, height: 300)

    @Test("goes below the selection when it fits")
    func belowWhenItFits() {
        let anchor = CGRect(x: 200, y: 600, width: 120, height: 18)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop])
        #expect(origin == CGPoint(x: 200, y: 600 - PopupPlacement.gap - 300))
    }

    @Test("flips above a selection near the bottom of the screen")
    func aboveNearTheBottom() {
        let anchor = CGRect(x: 200, y: 60, width: 120, height: 18)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop])
        #expect(origin == CGPoint(x: 200, y: 78 + PopupPlacement.gap))
    }

    @Test("pins to the top when it fits neither below nor above")
    func pinnedToTheTopWhenTooTall() {
        let anchor = CGRect(x: 200, y: 400, width: 120, height: 18)
        let tall = CGSize(width: 440, height: 600)
        let origin = PopupPlacement.origin(for: tall, anchor: anchor, screens: [Self.laptop])
        #expect(origin.y == 875 - PopupPlacement.margin - 600)
    }

    @Test("never goes below the bottom margin when taller than the screen")
    func tallerThanTheScreen() {
        let anchor = CGRect(x: 200, y: 400, width: 120, height: 18)
        let huge = CGSize(width: 440, height: 2000)
        let origin = PopupPlacement.origin(for: huge, anchor: anchor, screens: [Self.laptop])
        #expect(origin.y == PopupPlacement.margin)
    }

    @Test("stays inside the right edge")
    func clampedToTheRightEdge() {
        let anchor = CGRect(x: 1400, y: 600, width: 30, height: 18)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop])
        #expect(origin.x == 1440 - PopupPlacement.margin - 440)
    }

    @Test("stays inside the left edge")
    func clampedToTheLeftEdge() {
        let anchor = CGRect(x: -50, y: 600, width: 30, height: 18)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop])
        #expect(origin.x == PopupPlacement.margin)
    }

    @Test("uses the screen that holds the selection")
    func usesTheScreenOfTheSelection() {
        let anchor = CGRect(x: 3900, y: 1000, width: 80, height: 18)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop, Self.rightMonitor])
        #expect(origin.x == 1440 + 2560 - PopupPlacement.margin - 440)
        #expect(origin.y == 1000 - PopupPlacement.gap - 300)
    }

    @Test("falls back to the main screen when the selection is off every screen")
    func fallsBackToTheMainScreen() {
        let anchor = CGRect(x: 9000, y: 9000, width: 0, height: 0)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop, Self.rightMonitor], mainScreen: Self.rightMonitor)
        #expect(origin.x == 1440 + 2560 - PopupPlacement.margin - 440)
    }

    @Test("treats a zero-size anchor such as the mouse position like a selection")
    func mousePositionAnchor() {
        let anchor = CGRect(x: 700, y: 20, width: 0, height: 0)
        let origin = PopupPlacement.origin(for: Self.popup, anchor: anchor, screens: [Self.laptop])
        #expect(origin == CGPoint(x: 700, y: 20 + PopupPlacement.gap))
    }

    @Test("converts accessibility coordinates, whose origin is the top-left, to Cocoa ones")
    func accessibilityToCocoa() {
        let rect = PopupPlacement.cocoaRect(fromAccessibility: CGRect(x: 100, y: 50, width: 200, height: 20), primaryScreenHeight: 900)
        #expect(rect == CGRect(x: 100, y: 830, width: 200, height: 20))
    }
}
