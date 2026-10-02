import SwiftUI

/// 화면 아래에 잠깐 떴다 사라지는 안내.
struct MoaMapSnackbar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let message: String

    var body: some View {
        Text(message)
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textWhite)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(MoaMapPrimitiveColors.gray800, in: RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
    }
}

extension View {
    /// 값이 들어오면 바로 비우고 잠깐 띄운다. 띄우는 동안 다시 들어오면 새 안내로 바꾼다.
    func moaSnackbar(_ message: Binding<String?>, duration: Duration = .seconds(4)) -> some View {
        modifier(SnackbarModifier(message: message, duration: duration))
    }
}

private struct SnackbarModifier: ViewModifier {
    @Binding var message: String?
    let duration: Duration
    @State private var shown: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let shown {
                    MoaMapSnackbar(message: shown)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { self.shown = nil }
                }
            }
            .animation(.easeOut(duration: 0.2), value: shown)
            .onChange(of: message, initial: true) { _, arrived in
                guard let arrived else { return }
                shown = arrived
                message = nil
                UIAccessibility.post(notification: .announcement, argument: arrived)
            }
            .task(id: shown) {
                guard shown != nil else { return }
                try? await Task.sleep(for: duration)
                if !Task.isCancelled { shown = nil }
            }
    }
}

#Preview {
    Color.blue.opacity(0.2)
        .overlay(alignment: .bottom) { MoaMapSnackbar(message: "장소를 추가했어요") }
}
