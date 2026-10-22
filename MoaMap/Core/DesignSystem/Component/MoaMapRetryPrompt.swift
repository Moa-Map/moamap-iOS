import SwiftUI

/// 불러오기 실패 안내와 「다시 시도」 버튼.
struct MoaMapRetryPrompt: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
                .multilineTextAlignment(.center)
            Button("다시 시도", action: onRetry)
                .moaTextStyle(typography.button2)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .foregroundStyle(colors.textWhite)
                .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    MoaMapRetryPrompt(message: "약관을 불러오지 못했어요", onRetry: {})
}
