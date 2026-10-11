import SwiftUI

/// 피그마 로고(Group 3429). 그림은 그림자까지 담아 본체보다 크고, 본체는 그림 가운데에 있다.
/// 배치는 본체 크기로만 잡고 그림자는 바깥으로 번지게 둔다.
struct MoaSymbolLogo: View {
    /// 그림(120.252 x 102.352) ÷ 본체(108.5 x 90.601).
    private static let shadowScale = CGSize(width: 120.252 / 108.5, height: 102.352 / 90.601)

    let bodySize: CGSize

    var body: some View {
        Image("moa-symbol-large")
            .resizable()
            .frame(
                width: bodySize.width * Self.shadowScale.width,
                height: bodySize.height * Self.shadowScale.height
            )
            .frame(width: bodySize.width, height: bodySize.height)
            .accessibilityLabel("모아맵")
    }
}
