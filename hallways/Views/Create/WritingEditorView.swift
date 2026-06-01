import SwiftUI
import SwiftData
import UIKit

struct WritingEditorView: View {
    enum Mode {
        case create
        case edit(Piece)

        var existingPiece: Piece? {
            if case .edit(let p) = self { return p }
            return nil
        }

        var footerLabel: String {
            if case .edit = self { return "save" }
            return "publish"
        }
    }

    let mode: Mode
    var onCancel: () -> Void
    var onSave: (_ content: String) -> Void

    @State private var text: String = ""
    @State private var isFocused: Bool = false
    @State private var showCancelConfirm: Bool = false
    @State private var didSave: Bool = false
    @State private var didLoadInitial: Bool = false

    private let footerHeight: CGFloat = 40
    private let footerTopCurve: CGFloat = 48
    private let placeholder: String = "tell me my love"
    private let bodyFontSize: CGFloat = 24
    private let horizontalTextInset: CGFloat = 40

    private var bodyFont: UIFont {
        UIFont(name: "SpecialElite-Regular", size: bodyFontSize) ?? .systemFont(ofSize: bodyFontSize)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Bottom-most full-screen tap-dismiss backstop. Catches taps that
            // fall through the text view, footer, X, and paper-picker. Also
            // blocks taps from leaking through to the FeedView underneath
            // when this view is mounted as an overlay.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    if isFocused { dismissKeyboard() }
                }

            BulletTextView(
                text: $text,
                isFocused: $isFocused,
                font: bodyFont,
                textColor: UIColor(HallwaysTheme.text),
                tintColor: UIColor(HallwaysTheme.text),
                textInsets: UIEdgeInsets(
                    top: 24,
                    left: horizontalTextInset,
                    bottom: 24,
                    right: horizontalTextInset
                ),
                autoFocus: false
            )
            .overlay(alignment: .topLeading) {
                if text.isEmpty && !isFocused {
                    Text(placeholder)
                        .font(.specialElite(size: bodyFontSize))
                        .foregroundColor(HallwaysTheme.text.opacity(0.4))
                        .padding(.leading, horizontalTextInset)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 80)
            .padding(.bottom, footerHeight + footerTopCurve)

            publishFooter

            if showCancelConfirm {
                cancelConfirm
                    .transition(.opacity)
                    .zIndex(300)
            }
        }
        // Bg goes via .background, not as a ZStack child. .ignoresSafeArea
        // here only extends the *paint* beyond the safe area — the ZStack's
        // layout frame stays inside safe area, so the publishFooter aligned
        // at .bottom anchors above the home indicator (instead of below it).
        .background(
            Image("green-paper-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .topLeading) {
            quarterCircleButton
                .ignoresSafeArea(edges: [.top, .leading])
        }
        .overlay(alignment: .topTrailing) {
            paperPickerPlaceholder
                .padding(.top, 60)
                .padding(.trailing, 20)
                .ignoresSafeArea(edges: .top)
        }
        .onAppear { loadInitialState() }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Top widgets

    private var quarterCircleButton: some View {
        ZStack(alignment: .topLeading) {
            QuarterCircleShape()
                .fill(Color(hex: "FCFCFC").opacity(0.6))
                .frame(width: 130, height: 130)
                .allowsHitTesting(false)

            Button {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onCancel()
                } else {
                    dismissKeyboard()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCancelConfirm = true
                    }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, 60)
            .padding(.leading, 12)
        }
    }

    private var paperPickerPlaceholder: some View {
        Image("green-paper-bg")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(hex: "FCFCFC"), lineWidth: 2))
    }

    // MARK: - Publish footer

    private var publishFooter: some View {
        let canPublish = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                HallwaysTheme.text
                    .ignoresSafeArea(edges: .bottom)
                PublishSemicircleShape(
                    topCurveHeight: footerTopCurve,
                    bottomCurveHeight: 0
                )
                .fill(HallwaysTheme.text)
            }

            Text(mode.footerLabel)
                .font(.specialElite(size: 16))
                .foregroundColor(.white)
                .opacity(canPublish ? 1 : 0.4)
                .padding(.top, 24)
        }
        .frame(height: footerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canPublish, !didSave else { return }
            didSave = true
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onSave(text)
            }
        }
    }

    // MARK: - Cancel confirm

    private var cancelConfirm: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCancelConfirm = false
                    }
                }

            VStack(spacing: 20) {
                Text("are you sure?")
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCancelConfirm = false
                        }
                        onCancel()
                    } label: {
                        Text("yes")
                            .font(.specialElite(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(HallwaysTheme.text)
                            )
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCancelConfirm = false
                        }
                    } label: {
                        Text("no")
                            .font(.specialElite(size: 16))
                            .foregroundColor(HallwaysTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(HallwaysTheme.text, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(HallwaysTheme.background)
            )
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Initial state

    private func loadInitialState() {
        guard !didLoadInitial else { return }
        didLoadInitial = true
        if let piece = mode.existingPiece, let content = piece.textContent {
            text = content
        }
    }

}
