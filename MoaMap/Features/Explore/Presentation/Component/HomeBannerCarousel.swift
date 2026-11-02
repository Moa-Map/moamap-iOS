import SwiftUI

/// 홈 맨 위 배너 줄. 시안: 높이 170, 왼쪽 20 부터 카드 사이 8, 다음 카드가 오른쪽에 살짝 보인다.
///
/// 한 장씩 맞춰 넘긴다. 카드 폭은 화면에서 좌우 20 을 뺀 값이라 393 화면에서 시안의 353 이 된다.
struct HomeBannerCarousel: View {
    /// nil 이면 받는 중이라 자리만 비워 둔다. 비었으면 기본 배너 한 장을 보여 준다.
    let banners: [Banner]?

    var body: some View {
        if let banners {
            let urls: [URL?] = banners.isEmpty ? [nil] : banners.map(\.imageURL)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                        BannerCard(url: url)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, MoaMapDimens.screenHorizontalPadding, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .frame(height: BannerCard.height)
        } else {
            Color.clear.frame(height: BannerCard.height)
        }
    }
}

private struct BannerCard: View {
    @Environment(\.moaColors) private var colors

    static let height: CGFloat = 170

    /// nil 이면 기본 배너다.
    let url: URL?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)

        Color.clear
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty where url != nil:
                        Color.clear
                    default:
                        Image("home-banner-default").resizable().scaledToFill()
                    }
                }
            }
            .frame(height: Self.height)
            .clipShape(shape)
            // 시안 「탐색탭_배너」: 테두리 1 Line/Alternative 를 사진 위에 그린다.
            .overlay { shape.strokeBorder(colors.lineAlternative, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 32) {
        HomeBannerCarousel(banners: [])
        HomeBannerCarousel(banners: nil)
    }
    .padding(.vertical)
    .background(MoaMapPrimitiveColors.tabBackground)
}
