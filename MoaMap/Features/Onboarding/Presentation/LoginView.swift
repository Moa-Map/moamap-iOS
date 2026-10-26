import SwiftUI

struct LoginView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var loadingProvider: LoginProvider?
    var onKakaoLogin: (() -> Void)?
    var onAppleLogin: (() -> Void)?
    var onGoogleLogin: (() -> Void)?
    /// 로그인 뒤 약관 동의 여부를 확인하지 못했을 때의 안내. 있으면 아래쪽에 「다시 시도」·「로그아웃」과 함께 띄운다.
    var failureMessage: String?
    var onRetry: () -> Void = {}
    var onLogout: () -> Void = {}

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
                + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom

            ScrollView {
                // 피그마 「Home/」(4925:19953). 문구 묶음은 화면 위에서 200, 버튼 묶음은 화면 아래에서 118 에 둔다.
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("함께 모아, 더 특별해질 지도?")
                            .moaTextStyle(typography.subtitle1)
                            .foregroundStyle(colors.textNormal)
                        HStack(spacing: 12) {
                            MoaSymbolLogo(bodySize: CGSize(width: 60, height: 50.102))
                            Text("Moa Map")
                                .moaTextStyle(typography.display2)
                                .foregroundStyle(colors.textNormal)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.top, 200)

                    Spacer(minLength: 40)

                    VStack(spacing: 12) {
                        SocialLoginButton(
                            provider: .google,
                            isLoading: loadingProvider == .google,
                            action: onGoogleLogin
                        )
                        SocialLoginButton(
                            provider: .kakao,
                            isLoading: loadingProvider == .kakao,
                            action: onKakaoLogin
                        )
                        SocialLoginButton(
                            provider: .apple,
                            isLoading: loadingProvider == .apple,
                            action: onAppleLogin
                        )
                    }
                    .disabled(loadingProvider != nil || failureMessage != nil)
                    .padding(.bottom, 118)
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .frame(maxWidth: 480)
                .frame(minHeight: screenHeight)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .vertical)
        }
        .overlay(alignment: .bottom) {
            if let failureMessage {
                TermsCheckFailurePrompt(message: failureMessage, onRetry: onRetry, onLogout: onLogout)
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    .padding(.bottom, 24)
            }
        }
        // 시안 배경은 단색 Background/Primary(#E6F6FF)다. iOS 의 backgroundPrimary 토큰은 그라데이션이라 쓰지 않는다.
        .background { MoaMapPrimitiveColors.blue50.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }
}

#Preview("로그인") {
    LoginView()
}

#Preview("카카오 로그인 중") {
    LoginView(loadingProvider: .kakao)
}

#Preview("Apple 로그인 중") {
    LoginView(loadingProvider: .apple)
}

#Preview("동의 확인 실패") {
    LoginView(failureMessage: "약관 동의 여부를 확인하지 못했어요")
}
