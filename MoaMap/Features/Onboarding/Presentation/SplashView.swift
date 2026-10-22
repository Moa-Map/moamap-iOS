import SwiftUI

/// 피그마 「Splash/」(3552:18930). Android `SplashScreen` 과 같은 배치다.
struct SplashView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    /// 있으면 로고 아래에 안내와 「다시 시도」를 띄운다.
    var failureMessage: String?
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            MoaSymbolLogo(bodySize: CGSize(width: 108.5, height: 90.601))

            Text("취향을 담아,\n우리만의 지도로")
                .moaTextStyle(typography.display2)
                .multilineTextAlignment(.center)
                .foregroundStyle(colors.textNormal)
                .fixedSize(horizontal: false, vertical: true)
        }
        // 로고 묶음이 가운데에서 밀려나지 않게 아래에 붙인다.
        .overlay(alignment: .bottom) {
            if let failureMessage {
                MoaMapRetryPrompt(message: failureMessage, onRetry: onRetry)
                    .fixedSize()
                    .alignmentGuide(.bottom) { $0[.top] - 40 }
            }
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        // 시안은 안전 영역이 아니라 화면 전체의 가운데에 둔다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }
}

#Preview {
    SplashView()
}

#Preview("동의 확인 실패") {
    SplashView(failureMessage: "약관 동의 여부를 확인하지 못했어요")
}
