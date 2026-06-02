import SwiftUI
import SwiftData
import UIKit

struct WritingEditorView: View {
    enum Mode {
        case create
        case edit(Piece)
        // Sub-screen used by the combined-collection edit overview.
        // No own save button — back arrow auto-commits the current text
        // via onCommit. Persistence happens on the overview.
        case branch(initialText: String, onCommit: (String) -> Void)

        var existingPiece: Piece? {
            if case .edit(let p) = self { return p }
            return nil
        }

        var initialBranchText: String? {
            if case .branch(let initial, _) = self { return initial }
            return nil
        }

        var branchCommit: ((String) -> Void)? {
            if case .branch(_, let commit) = self { return commit }
            return nil
        }

        var isBranch: Bool {
            if case .branch = self { return true }
            return false
        }

        var footerLabel: String {
            if case .edit = self { return "save" }
            return "publish"
        }
    }

    let mode: Mode
    var onCancel: () -> Void
    var onSave: (_ content: String) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var text: String = ""
    @State private var isFocused: Bool = false
    @State private var showCancelConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var didSave: Bool = false
    @State private var didLoadInitial: Bool = false

    private let footerHeight: CGFloat = 40
    private let footerTopCurve: CGFloat = 48
    private let placeholder: String = "tell me my love"
    private let bodyFontSize: CGFloat = 18
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
                bottomClearance: mode.isBranch ? 24 : footerHeight + footerTopCurve + 8,
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

            if !mode.isBranch {
                publishFooter
            }

            if showCancelConfirm {
                confirmPrompt(
                    message: "are you sure?",
                    yesLabel: "yes",
                    noLabel: "no",
                    onYes: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCancelConfirm = false
                        }
                        onCancel()
                    },
                    onNo: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCancelConfirm = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(300)
            }

            if showDeleteConfirm {
                confirmPrompt(
                    message: "delete this piece?",
                    yesLabel: "delete",
                    noLabel: "cancel",
                    onYes: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showDeleteConfirm = false
                        }
                        onDelete?()
                    },
                    onNo: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showDeleteConfirm = false
                        }
                    }
                )
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
            HStack(spacing: 12) {
                if case .edit = mode {
                    Button {
                        dismissKeyboard()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(HallwaysTheme.text)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
                paperPickerPlaceholder
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
            .ignoresSafeArea(edges: .top)
            .opacity(mode.isBranch ? 0 : 1)
            .allowsHitTesting(!mode.isBranch)
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
                if mode.isBranch {
                    dismissKeyboard()
                    mode.branchCommit?(text)
                    onCancel()
                } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onCancel()
                } else {
                    dismissKeyboard()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCancelConfirm = true
                    }
                }
            } label: {
                Image(systemName: mode.isBranch ? "chevron.left" : "xmark")
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
                HalfMoonCTA(
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

    // MARK: - Confirm prompt

    private func confirmPrompt(
        message: String,
        yesLabel: String,
        noLabel: String,
        onYes: @escaping () -> Void,
        onNo: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onNo() }

            VStack(spacing: 20) {
                Text(message)
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button(action: onYes) {
                        Text(yesLabel)
                            .font(.specialElite(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(HallwaysTheme.text)
                            )
                    }

                    Button(action: onNo) {
                        Text(noLabel)
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
        } else if let initial = mode.initialBranchText {
            text = initial
        }
    }

}
