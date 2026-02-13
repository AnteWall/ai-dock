import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = .init(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false

        positionAtNotch()
    }

    /// Position the panel just below the menu bar, avoiding the camera notch on MacBooks.
    func positionAtNotch() {
        guard let screen = NotchLayoutMetrics.currentScreen() else { return }
        let metrics = NotchLayoutMetrics.forScreen(screen)
        let screenFrame = screen.frame
        let panelWidth = frame.width
        let x = metrics.centerX - panelWidth / 2
        // Pin to very top edge.
        let y = screenFrame.maxY - frame.height
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateSize(width: CGFloat, height: CGFloat, animated: Bool = true) {
        guard let screen = NotchLayoutMetrics.currentScreen() else { return }
        let metrics = NotchLayoutMetrics.forScreen(screen)
        let screenFrame = screen.frame
        let newX = metrics.centerX - width / 2
        let newY = screenFrame.maxY - height

        let newFrame = NSRect(x: newX, y: newY, width: width, height: height)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.0)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
