import SwiftUI

enum ViewMode {
    case minimalist
    case file
}

struct ViewModeToggle: View {
    @Binding var viewMode: ViewMode

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewMode = viewMode == .minimalist ? .file : .minimalist
            }
        } label: {
            ZStack(alignment: viewMode == .minimalist ? .leading : .trailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(HallwaysTheme.text)
                    .frame(width: 80, height: 44)

                RoundedRectangle(cornerRadius: 6)
                    .fill(.white)
                    .frame(width: 30, height: 30)
                    .padding(7)
            }
        }
    }
}
