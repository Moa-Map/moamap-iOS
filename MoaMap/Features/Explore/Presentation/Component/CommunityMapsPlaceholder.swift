import SwiftUI

/// 목록 자리에 로딩·오류·빈 상태를 같은 높이로 앉혀 화면이 튀지 않게 한다.
struct CommunityMapsPlaceholder<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 200)
    }
}

struct CommunityMapsError: View {
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
                .foregroundStyle(colors.textNormal)
                .buttonStyle(.plain)
        }
    }
}

#Preview {
    CommunityMapsPlaceholder {
        CommunityMapsError(message: "지도 목록을 불러오지 못했어요") {}
    }
}
