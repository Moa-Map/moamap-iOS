import SwiftUI

/// 피그마 「Splash/」(3552:18930). Android `SplashScreen` 과 같은 배치다.
struct SplashView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    /// 있으면 화면 아래쪽에 안내와 「다시 시도」·「로그아웃」을 띄운다. 로그인 화면과 같은 자리다.
    var failureMessage: String?
    var onRetry: () -> Void = {}
    var onLogout: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                MoaSymbolLogo(bodySize: CGSize(width: 108.5, height: 90.601))

                Text("취향을 담아,\n우리만의 지도로")
                    .moaTextStyle(typography.display2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(colors.textNormal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            // 시안은 안전 영역이 아니라 화면 전체의 가운데에 둔다.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // 안내는 안전 영역 안에 둔다.
            if let failureMessage {
                TermsCheckFailurePrompt(message: failureMessage, onRetry: onRetry, onLogout: onLogout)
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    .padding(.bottom, 24)
            }
        }
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
