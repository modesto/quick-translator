import CoreGraphics

public struct ScreenArea: Equatable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum PopupPlacement {
    public static let margin: CGFloat = 8
    public static let gap: CGFloat = 6
    static let fallbackVisibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    public static func origin(for size: CGSize, anchor: CGRect, screens: [ScreenArea], mainScreen: ScreenArea? = nil) -> CGPoint {
        let center = CGPoint(x: anchor.midX, y: anchor.midY)
        let screen = screens.first { $0.frame.contains(center) } ?? mainScreen ?? screens.first
        let visible = screen?.visibleFrame ?? fallbackVisibleFrame

        let spaceBelow = anchor.minY - visible.minY - margin - gap
        let spaceAbove = visible.maxY - anchor.maxY - margin - gap
        let y: CGFloat
        if size.height <= spaceBelow {
            y = anchor.minY - gap - size.height
        } else if size.height <= spaceAbove {
            y = anchor.maxY + gap
        } else {
            y = visible.maxY - margin - size.height
        }

        let x = min(max(anchor.minX, visible.minX + margin), visible.maxX - margin - size.width)
        return CGPoint(x: x, y: max(y, visible.minY + margin))
    }

    public static func origin(keepingTopOf frame: CGRect, for size: CGSize, screens: [ScreenArea], mainScreen: ScreenArea? = nil) -> CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = screens.first { $0.frame.contains(center) } ?? mainScreen ?? screens.first
        let visible = screen?.visibleFrame ?? fallbackVisibleFrame
        let y = max(frame.maxY - size.height, visible.minY + margin)
        return CGPoint(x: frame.minX, y: min(y, visible.maxY - size.height))
    }

    public static func draggedOrigin(from windowOrigin: CGPoint, mouseStart: CGPoint, mouse: CGPoint) -> CGPoint {
        CGPoint(x: windowOrigin.x + mouse.x - mouseStart.x, y: windowOrigin.y + mouse.y - mouseStart.y)
    }

    public static func cocoaRect(fromAccessibility rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
