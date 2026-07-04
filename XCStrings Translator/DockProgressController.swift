//
//  DockProgressController.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import AppKit

/// Main-actor AppKit bridge for showing translation progress in the Dock tile.
///
/// SwiftUI does not expose Dock tile drawing APIs, so this controller owns the small
/// AppKit surface needed by `ContentView`. It is intentionally isolated from the rest
/// of the workflow to keep platform-specific drawing code out of SwiftUI views.
@MainActor
final class DockProgressController {
    /// Shared controller used by the single-window app.
    static let shared = DockProgressController()

    /// Dock tile for the running application.
    private let dockTile = NSApplication.shared.dockTile

    /// Creates the singleton controller.
    private init() {}

    /// Updates the Dock progress overlay.
    ///
    /// - Parameters:
    ///   - progress: Normalized progress value. Values outside `0...1` are clamped.
    ///   - isVisible: Whether the overlay should be shown.
    ///
    /// Side Effects:
    /// Creates or updates `dockTile.contentView` and requests a Dock tile redraw.
    func update(progress: Double, isVisible: Bool) {
        guard isVisible else {
            clear()
            return
        }

        // Reuse the dock tile view between progress updates. Replacing it every tick
        // causes unnecessary AppKit drawing work while translation is running.
        let progressView: DockProgressView

        if let existingView = dockTile.contentView as? DockProgressView {
            progressView = existingView
        } else {
            progressView = DockProgressView(
                frame: NSRect(origin: .zero, size: dockTile.size)
            )
            dockTile.contentView = progressView
        }

        progressView.progress = min(max(progress, 0), 1)
        dockTile.display()
    }

    /// Removes the custom Dock tile overlay and restores the default app icon.
    ///
    /// Side Effects:
    /// Clears `dockTile.contentView` and redraws the Dock tile.
    func clear() {
        guard dockTile.contentView != nil else {
            return
        }

        dockTile.contentView = nil
        dockTile.display()
    }
}

/// Dock tile content view that draws the app icon plus a progress bar.
private final class DockProgressView: NSView {
    /// Normalized progress value used when drawing the fill bar.
    var progress: Double = 0 {
        didSet {
            needsDisplay = true
        }
    }

    /// Draws the app icon and progress overlay.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the normal app icon first, then overlay a compact progress bar at the
        // bottom so the Dock continues to identify the app clearly.
        NSApplication.shared.applicationIconImage.draw(in: bounds)
        drawProgressTrack()
        drawProgressFill()
    }

    /// Draws the dark translucent progress track.
    private func drawProgressTrack() {
        NSColor.black.withAlphaComponent(0.38).setFill()
        progressRect()
            .rounded(radius: 4)
            .fill()
    }

    /// Draws the accent-colored progress fill.
    private func drawProgressFill() {
        guard progress > 0 else {
            return
        }

        let trackRect = progressRect()
        let fillRect = NSRect(
            x: trackRect.minX,
            y: trackRect.minY,
            width: trackRect.width * progress,
            height: trackRect.height
        )

        NSColor.controlAccentColor.setFill()
        fillRect
            .rounded(radius: 4)
            .fill()
    }

    /// Computes the track rectangle relative to the current Dock tile bounds.
    private func progressRect() -> NSRect {
        let horizontalInset = bounds.width * 0.14
        return NSRect(
            x: bounds.minX + horizontalInset,
            y: bounds.minY + 8,
            width: bounds.width - (horizontalInset * 2),
            height: 9
        )
    }
}

/// Convenience drawing helper for rounded AppKit rectangles.
private extension NSRect {
    /// Creates a rounded path matching this rectangle.
    ///
    /// - Parameter radius: Corner radius for both axes.
    /// - Returns: Rounded rectangle path ready to fill or stroke.
    func rounded(radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: self, xRadius: radius, yRadius: radius)
    }
}
