import SwiftUI

/// 피그마 「Splash/」(3552:18930). Android `SplashScreen` 과 같은 배치다.
struct SplashView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var body: some View {
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
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }
}

#Preview {
    SplashView()
}
