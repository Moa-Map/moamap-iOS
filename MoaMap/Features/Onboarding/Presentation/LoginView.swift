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
            // 화면 전체 기준 가운데를 지키면서 넘칠 때도 상태 바·홈 인디케이터를 피하도록 위아래를 같게 비운다.
            let verticalInset = max(geometry.safeAreaInsets.top, geometry.safeAreaInsets.bottom) + 24

            ScrollView {
                // 피그마 「Home/」(3258:12942). 로고·문구·버튼 묶음을 화면 전체의 세로 가운데에 둔다.
                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                        MoaSymbolLogo(bodySize: CGSize(width: 103.991, height: 83.588))

                        Text("취향을 담아,\n우리만의 지도로")
                            .moaTextStyle(typography.display2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(colors.textNormal)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.vertical, verticalInset)
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
