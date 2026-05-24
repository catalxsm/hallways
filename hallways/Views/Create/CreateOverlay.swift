import SwiftUI

struct CreateOverlay: View {
    var onDismiss: () -> Void
    var onUploadMedia: () -> Void
    var onWriting: () -> Void

    var body: some View {
        ZStack {
            HallwaysTheme.background.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                Spacer()

                // Two action labels, staggered vertically (writing slightly lower-left,
                // upload-media higher-right) per reference.
                VStack(alignment: .trailing, spacing: 12) {
                    pillButton(title: "upload media", action: onUploadMedia)
                        .padding(.trailing, 24)

                    pillButton(title: "writing", action: onWriting)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                }
                .padding(.bottom, 24)

                // Dismiss chevron — sits where the + button does, replacing it visually.
                HStack {
                    Button(action: onDismiss) {
                        ZStack {
                            Circle()
                                .fill(HallwaysTheme.text)
                                .frame(width: 52, height: 52)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private func pillButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.printvetica(size: 18))
                .foregroundColor(HallwaysTheme.text)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                // CTA size — bump width / height for bigger buttons.
                .frame(minWidth: 160, minHeight: 56)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}
