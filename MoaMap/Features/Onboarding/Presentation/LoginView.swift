import SwiftUI

struct LoginView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var loadingProvider: LoginProvider?
    var onKakaoLogin: (() -> Void)?
    var onAppleLogin: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
                + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Image("moa-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 173, height: 103)
                            .accessibilityLabel("모아맵")

                        Text("취향을 담아,\n우리만의 지도로")
                            .moaTextStyle(typography.title1)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(colors.textNormal)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Color.clear.frame(height: screenHeight * 66 / 852)

                    VStack(spacing: 12) {
                        SocialLoginButton(provider: .google)
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
                    .disabled(loadingProvider != nil)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, max(24, screenHeight * 239 / 852 - geometry.safeAreaInsets.top))
                .frame(maxWidth: 480)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
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
