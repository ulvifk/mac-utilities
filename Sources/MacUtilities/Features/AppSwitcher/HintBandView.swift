import AppKit

/// The band the panel grows along its bottom edge: a tray of the shortcut hints that fit its width, or for a moment in its place a tray saying
/// what a shortcut just did, both centered. Shows neither until told to.
final class HintBandView: NSView {
    private var hintTray = NSView()
    private var feedbackTray = NSView()

    /// What the hint tray was built for.
    private var trayHints: [ShortcutHint] = []
    private var trayWidth: CGFloat = 0

    convenience init() {
        self.init(frame: .zero)
        hintTray.alphaValue = 0
    }

    /// Fitted to the width the band ends up with and centered on its current one, so it stays centered while the band's width animates there.
    /// Whether the hints show is kept. The tray is rebuilt only when the hints or the width changed: the selection moves inside the tap
    /// callback, and most moves leave the hints as they were.
    func setHints(_ hints: [ShortcutHint], width: CGFloat) {
        if isTrayBuilt(for: hints, width: width) { return }

        let tray = buildHintTray(hints, width: width)

        tray.alphaValue = hintTray.alphaValue
        hintTray.removeFromSuperview()
        hintTray = tray
        trayHints = hints
        trayWidth = width
        addSubview(tray)
    }

    func showHints() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hintFadeDuration
            hintTray.animator().alphaValue = 1
            feedbackTray.animator().alphaValue = 0
        }
    }

    /// In place of the hints, or of the feedback before it.
    func showFeedback(_ feedback: SwitcherFeedback, width: CGFloat) {
        let previousTray = feedbackTray
        let tray = buildFeedbackTray(feedback, width: width)

        tray.alphaValue = 0
        addSubview(tray)
        feedbackTray = tray

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = hintFadeDuration
            hintTray.animator().alphaValue = 0
            previousTray.animator().alphaValue = 0
            tray.animator().alphaValue = 1
        }, completionHandler: {
            previousTray.removeFromSuperview()
        })
    }

    /// Shows neither again, for the next time the panel opens.
    func clear() {
        hintTray.alphaValue = 0
        feedbackTray.removeFromSuperview()
    }

    private func isTrayBuilt(for hints: [ShortcutHint], width: CGFloat) -> Bool {
        if hints != trayHints { return false }
        return width == trayWidth
    }

    /// The hints side by side in order; each one that would run the tray past its side insets is left out, so the first ones stay the longest
    /// as the panel narrows.
    private func buildHintTray(_ hints: [ShortcutHint], width: CGFloat) -> NSView {
        let maxHintsWidth = width - 2 * hintTraySideInset - hintTrayPadding - hintTrayTrailingPadding
        var hintViews: [NSView] = []
        var hintsWidth: CGFloat = 0

        for hint in hints {
            let hintView = buildHintView(hint)
            let x = hintViews.isEmpty ? 0 : hintsWidth + hintSpacing
            if x + hintView.frame.width > maxHintsWidth { continue }

            hintView.frame = alignToPixels(hintView.frame.offsetBy(dx: hintTrayPadding + x, dy: hintTrayPadding))
            hintViews.append(hintView)
            hintsWidth = x + hintView.frame.width
        }

        let tray = buildTray(width: hintTrayPadding + hintsWidth + hintTrayTrailingPadding, color: hintTrayColor)
        for hintView in hintViews {
            tray.addSubview(hintView)
        }

        return tray
    }

    /// The keys in a keycap, then what they do.
    private func buildHintView(_ hint: ShortcutHint) -> NSView {
        let keycap = buildKeycap(keys: hint.keys)
        let action = NSTextField(labelWithString: hint.action)

        action.font = .systemFont(ofSize: 11, weight: .medium)
        action.textColor = hintActionColor

        let actionSize = action.fittingSize
        action.frame = alignToPixels(NSRect(
            x: keycap.frame.maxX + hintKeycapActionSpacing,
            y: (hintKeycapHeight - actionSize.height) / 2,
            width: actionSize.width,
            height: actionSize.height
        ))

        let hintView = NSView(frame: NSRect(x: 0, y: 0, width: action.frame.maxX, height: hintKeycapHeight))
        hintView.addSubview(keycap)
        hintView.addSubview(action)

        return hintView
    }

    /// A rounded key at least as wide as it is tall, the keys centered on it.
    private func buildKeycap(keys: String) -> NSView {
        let label = NSTextField(labelWithString: keys)

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white

        let labelSize = label.fittingSize
        let width = max(hintKeycapHeight, labelSize.width + 2 * hintKeycapHorizontalPadding)
        label.frame = alignToPixels(NSRect(x: (width - labelSize.width) / 2, y: (hintKeycapHeight - labelSize.height) / 2, width: labelSize.width, height: labelSize.height))

        let keycap = NSView(frame: alignToPixels(NSRect(x: 0, y: 0, width: width, height: hintKeycapHeight)))
        keycap.wantsLayer = true
        keycap.layer?.cornerRadius = hintKeycapCornerRadius
        keycap.layer?.backgroundColor = hintKeycapColor.cgColor
        keycap.addSubview(label)

        return keycap
    }

    /// The feedback's symbol and text on a tray of its colour, no wider than the hint tray may be, truncating a longer text.
    private func buildFeedbackTray(_ feedback: SwitcherFeedback, width: CGFloat) -> NSView {
        let symbol = NSImageView(image: NSImage(systemSymbolName: feedback.symbolName, accessibilityDescription: nil)!)
        let label = NSTextField(labelWithString: feedback.text)

        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .heavy)
        symbol.contentTintColor = .white
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail

        let symbolSize = symbol.fittingSize
        let labelSize = label.fittingSize
        let fittingWidth = feedbackTrayPadding + symbolSize.width + feedbackSymbolSpacing + labelSize.width + feedbackTrayPadding
        let tray = buildTray(width: min(fittingWidth, width - 2 * hintTraySideInset), color: feedback.color)

        symbol.frame = alignToPixels(NSRect(x: feedbackTrayPadding, y: (hintTrayHeight - symbolSize.height) / 2, width: symbolSize.width, height: symbolSize.height))
        let labelX = symbol.frame.maxX + feedbackSymbolSpacing
        label.frame = alignToPixels(NSRect(
            x: labelX,
            y: (hintTrayHeight - labelSize.height) / 2,
            width: tray.frame.width - labelX - feedbackTrayPadding,
            height: labelSize.height
        ))
        tray.addSubview(symbol)
        tray.addSubview(label)

        return tray
    }

    /// Centered on the band's current width, so it stays centered while the band's width animates.
    private func buildTray(width: CGFloat, color: NSColor) -> NSView {
        let tray = NSView(frame: alignToPixels(NSRect(x: (bounds.width - width) / 2, y: hintTrayBottomPadding, width: width, height: hintTrayHeight)))

        tray.autoresizingMask = [.minXMargin, .maxXMargin]
        tray.wantsLayer = true
        tray.layer?.cornerRadius = hintTrayCornerRadius
        tray.layer?.backgroundColor = color.cgColor

        return tray
    }
}
