import SwiftUI

/// 약관 동의 여부를 확인하지 못했을 때의 안내. 다시 시도하거나 로그아웃해 빠져나갈 수 있다.
struct TermsCheckFailurePrompt: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let message: String
    let onRetry: () -> Void
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            MoaMapRetryPrompt(message: message, onRetry: onRetry)
            Button(action: onLogout) {
                Text("로그아웃")
                    .moaTextStyle(typography.button3)
                    .underline()
                    .foregroundStyle(colors.textAssistive)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    TermsCheckFailurePrompt(message: "약관 동의 여부를 확인하지 못했어요", onRetry: {}, onLogout: {})
}
