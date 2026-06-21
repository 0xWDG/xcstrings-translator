//
//  DockProgressController.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import AppKit

@MainActor
final class DockProgressController {
    static let shared = DockProgressController()

    private let dockTile = NSApplication.shared.dockTile

    private init() {}

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

    func clear() {
        guard dockTile.contentView != nil else {
            return
        }

        dockTile.contentView = nil
        dockTile.display()
    }
}

private final class DockProgressView: NSView {
    var progress: Double = 0 {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the normal app icon first, then overlay a compact progress bar at the
        // bottom so the Dock continues to identify the app clearly.
        NSApplication.shared.applicationIconImage.draw(in: bounds)
        drawProgressTrack()
        drawProgressFill()
    }

    private func drawProgressTrack() {
        NSColor.black.withAlphaComponent(0.38).setFill()
        progressRect()
            .rounded(radius: 4)
            .fill()
    }

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

private extension NSRect {
    func rounded(radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: self, xRadius: radius, yRadius: radius)
    }
}
