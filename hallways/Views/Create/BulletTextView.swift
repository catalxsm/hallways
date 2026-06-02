import SwiftUI
import UIKit

// UITextView bridge with bullet-list smart formatting. SwiftUI's TextEditor
// doesn't expose the delegate hooks we need (shouldChangeTextIn) or scroll
// indicators, so we drop down to UIKit.
struct BulletTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var font: UIFont
    var textColor: UIColor
    var tintColor: UIColor
    var textInsets: UIEdgeInsets = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
    // Bottom scroll inset when keyboard is down. Lets callers reserve room so
    // the last line can be scrolled past content stacked on top of the text
    // view (e.g. the writing editor's publish dome).
    var bottomClearance: CGFloat = 24
    var autoFocus: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, bottomClearance: bottomClearance)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = font
        tv.textColor = textColor
        tv.tintColor = tintColor
        tv.backgroundColor = .clear
        tv.showsVerticalScrollIndicator = true
        tv.alwaysBounceVertical = true
        tv.textContainerInset = textInsets
        tv.textContainer.lineFragmentPadding = 0
        tv.keyboardDismissMode = .interactive
        // iOS would otherwise convert "--" into an em dash before our "- " → "•"
        // rule has a chance to fire.
        tv.smartDashesType = .no
        tv.text = text
        tv.contentInset.bottom = bottomClearance
        tv.verticalScrollIndicatorInsets.bottom = bottomClearance
        context.coordinator.attach(to: tv)

        // Tap inside the text view, but outside the rendered text (with a small
        // "right next to" padding), dismisses the keyboard. shouldReceive gates
        // on hit-test so UITextView's built-in cursor-placement tap still wins
        // when the user taps directly on text.
        let dismissTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleEmptyAreaTap)
        )
        dismissTap.delegate = context.coordinator
        tv.addGestureRecognizer(dismissTap)
        context.coordinator.emptyAreaTap = dismissTap

        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tv.becomeFirstResponder()
            }
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.font != font {
            uiView.font = font
        }
        if uiView.textContainerInset != textInsets {
            uiView.textContainerInset = textInsets
        }
        if context.coordinator.bottomClearance != bottomClearance {
            context.coordinator.bottomClearance = bottomClearance
            if uiView.contentInset.bottom != bottomClearance {
                uiView.contentInset.bottom = bottomClearance
                uiView.verticalScrollIndicatorInsets.bottom = bottomClearance
            }
        }
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var bottomClearance: CGFloat
        weak var emptyAreaTap: UITapGestureRecognizer?
        private weak var textView: UITextView?
        private var observers: [NSObjectProtocol] = []
        // Tap is "right next to" text within this many points.
        private let textHitPadding: CGFloat = 20

        init(text: Binding<String>, isFocused: Binding<Bool>, bottomClearance: CGFloat) {
            self.text = text
            self.isFocused = isFocused
            self.bottomClearance = bottomClearance
        }

        func attach(to textView: UITextView) {
            self.textView = textView
            let token = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handleKeyboard(note: note, hiding: false)
            }
            let hide = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handleKeyboard(note: note, hiding: true)
            }
            observers = [token, hide]
        }

        func detach() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
        }

        // MARK: - Keyboard tracking

        private func handleKeyboard(note: Notification, hiding: Bool) {
            guard let tv = textView, tv.window != nil else { return }
            let baseBottom: CGFloat = bottomClearance
            if hiding {
                tv.contentInset.bottom = baseBottom
                tv.verticalScrollIndicatorInsets.bottom = baseBottom
                return
            }
            guard let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            let tvFrameInWindow = tv.convert(tv.bounds, to: nil)
            let overlap = max(0, tvFrameInWindow.maxY - frame.minY)
            // Keep cursor at least 40pt above the keyboard.
            let bottomInset = overlap + 40
            tv.contentInset.bottom = bottomInset
            tv.verticalScrollIndicatorInsets.bottom = bottomInset
            if let range = tv.selectedTextRange {
                let caret = tv.caretRect(for: range.end)
                tv.scrollRectToVisible(caret, animated: true)
            }
        }

        // MARK: - Editing

        func textViewDidChange(_ tv: UITextView) {
            text.wrappedValue = tv.text
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            if !isFocused.wrappedValue { isFocused.wrappedValue = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            if isFocused.wrappedValue { isFocused.wrappedValue = false }
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            let nsText = tv.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let lineStart = lineRange.location
            let lineSoFar = nsText.substring(with: NSRange(location: lineStart, length: range.location - lineStart))

            // 1. Hyphen-space at start of line → bullet.
            if replacement == " " && lineSoFar == "-" {
                let strip = NSRange(location: range.location - 1, length: 1 + range.length)
                let updated = nsText.replacingCharacters(in: strip, with: "• ")
                tv.text = updated
                tv.selectedRange = NSRange(location: lineStart + 2, length: 0)
                text.wrappedValue = tv.text
                return false
            }

            // 2. Enter on bulleted line.
            if replacement == "\n" {
                let lineContent = trimmedLine(nsText, lineRange: lineRange)
                if lineContent == "• " {
                    // Empty bullet → strip the bullet, no newline inserted.
                    let strip = NSRange(location: lineStart, length: 2)
                    let updated = nsText.replacingCharacters(in: strip, with: "")
                    tv.text = updated
                    tv.selectedRange = NSRange(location: lineStart, length: 0)
                    text.wrappedValue = tv.text
                    return false
                }
                if lineSoFar.hasPrefix("• ") {
                    let updated = nsText.replacingCharacters(in: range, with: "\n• ")
                    tv.text = updated
                    tv.selectedRange = NSRange(location: range.location + 3, length: 0)
                    text.wrappedValue = tv.text
                    return false
                }
            }

            // 3. Backspace inside an empty bullet line → delete the whole "• ".
            if replacement.isEmpty && range.length == 1 {
                let lineContent = trimmedLine(nsText, lineRange: lineRange)
                if lineContent == "• " {
                    let strip = NSRange(location: lineStart, length: 2)
                    let updated = nsText.replacingCharacters(in: strip, with: "")
                    tv.text = updated
                    tv.selectedRange = NSRange(location: lineStart, length: 0)
                    text.wrappedValue = tv.text
                    return false
                }
            }

            return true
        }

        private func trimmedLine(_ nsText: NSString, lineRange: NSRange) -> String {
            var line = nsText.substring(with: lineRange)
            if line.hasSuffix("\n") { line.removeLast() }
            return line
        }

        // MARK: - Empty-area tap → dismiss

        @objc func handleEmptyAreaTap() {
            textView?.resignFirstResponder()
        }

        // Only let our recognizer fire when the touch is outside the rendered
        // text bounds (plus a small "right next to" padding). Returning false
        // leaves UITextView's built-in tap recognizer untouched so cursor
        // placement still works when the user taps directly on text.
        //
        // Also gate on `isFirstResponder` so taps on an unfocused empty
        // text view (e.g. tapping the placeholder) reliably focus the view —
        // otherwise our dismiss recognizer races UITextView's focus tap.
        func gestureRecognizer(_ gr: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gr === emptyAreaTap, let tv = textView else { return true }
            guard tv.isFirstResponder else { return false }
            let location = touch.location(in: tv)
            let textRect = textContentRect(in: tv)
            let padded = textRect.insetBy(dx: -textHitPadding, dy: -textHitPadding)
            return !padded.contains(location)
        }

        private func textContentRect(in tv: UITextView) -> CGRect {
            let inset = tv.textContainerInset
            // Force layout so usedRect reflects current content.
            tv.layoutManager.ensureLayout(for: tv.textContainer)
            let used = tv.layoutManager.usedRect(for: tv.textContainer)
            return CGRect(
                x: used.minX + inset.left,
                y: used.minY + inset.top,
                width: used.width,
                height: used.height
            )
        }
    }
}
