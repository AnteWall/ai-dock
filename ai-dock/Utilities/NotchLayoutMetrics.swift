import AppKit
import CoreGraphics

nonisolated struct NotchLayoutMetrics: Sendable {
    let hasCameraCutout: Bool
    let cameraGapWidth: CGFloat
    let centerX: CGFloat

    static func currentScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
    }

    static func forScreen(_ screen: NSScreen) -> NotchLayoutMetrics {
        if #available(macOS 12.0, *) {
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                let rawGap = right.minX - left.maxX
                if left.width > 0, right.width > 0, rawGap > 0 {
                let paddedGap = rawGap + 24
                let center = left.maxX + (rawGap / 2)
                return NotchLayoutMetrics(
                    hasCameraCutout: true,
                    cameraGapWidth: paddedGap,
                    centerX: center
                )
            }
            }
        }

        return NotchLayoutMetrics(
            hasCameraCutout: false,
            cameraGapWidth: 0,
            centerX: screen.frame.midX
        )
    }

    static func current() -> NotchLayoutMetrics {
        guard let screen = currentScreen() else {
            return NotchLayoutMetrics(hasCameraCutout: false, cameraGapWidth: 0, centerX: 0)
        }
        return forScreen(screen)
    }
}
