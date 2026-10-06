import SwiftUI

/// 홈 맨 위 운영자 추천 지도 카드 한 장.
///
/// 운영자 추천 지도 API 가 아직 없어 `mocks` 로 채운다(안드로이드와 같은 결정).
/// API 가 생기면 서버 응답에서 만들고, 누르면 그 지도로 가게 한다.
nonisolated struct FeaturedMap: Identifiable, Hashable, Sendable {
    let id: Int
    let description: String
    let title: String
    let tags: [String]
    /// 에셋 이름.
    let image: String

    /// 시안 「메인 화면」 히어로에 들어 있는 내용 그대로의 임시 데이터.
    static let mocks: [FeaturedMap] = (0..<3).map {
        FeaturedMap(
            id: $0,
            description: "운동 많이 된다...",
            title: "서울 필수 러닝 코스 추천 맵",
            tags: Array(repeating: "러닝맵 바로가기", count: 3),
            image: "home-hero-mock"
        )
    }
}

/// 운영자 추천 지도 카드 줄. 시안: 높이 150, 왼쪽 20 부터 카드 사이 8, 다음 카드가 오른쪽에 살짝 보인다.
///
/// 한 장씩 맞춰 넘긴다. 카드 폭은 화면에서 좌우 20 을 뺀 값이라 393 화면에서 시안의 353 이 된다.
struct FeaturedMapCarousel: View {
    let maps: [FeaturedMap]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(maps) { map in
                    FeaturedMapCard(map: map)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, MoaMapDimens.screenHorizontalPadding, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .frame(height: FeaturedMapCard.height)
    }
}

private struct FeaturedMapCard: View {
    static let height: CGFloat = 150

    let map: FeaturedMap

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)

        ZStack(alignment: .topLeading) {
            Color.clear
                .overlay {
                    Image(map.image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
            // 사진 위 덮개: 아래로 갈수록 어두워지는 그라데이션 + 전체 검정 8%. 시안 값.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.27),
                    .init(color: .black.opacity(0.41), location: 0.56),
                    .init(color: .black.opacity(0.6), location: 0.81)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Color.black.opacity(0.08)

            VStack(alignment: .leading, spacing: 0) {
                titleLine(map.description)
                titleLine(map.title)
            }
            .frame(width: 242, alignment: .leading)
            .padding(.leading, 12)
            .padding(.top, 52)

            HStack(spacing: 4) {
                ForEach(Array(map.tags.enumerated()), id: \.offset) { _, tag in
                    FeaturedTagChip(text: tag)
                }
            }
            .padding(.leading, 10)
            .padding(.top, 116)
        }
        .frame(height: Self.height)
        .clipShape(shape)
        .accessibilityElement(children: .combine)
    }

    private func titleLine(_ text: String) -> some View {
        Text(text)
            .moaTextStyle(Self.titleStyle)
            .foregroundStyle(MoaMapPrimitiveColors.white)
            .lineLimit(1)
            .shadow(color: .black.opacity(0.2), radius: 5)
    }

    /// 시안 히어로 글: ExtraBold 22, 줄 높이 1.3, 자간 −0.02em. 글꼴 단계에 22 가 없어 따로 둔다.
    private static let titleStyle = MoaMapTextStyle(
        fontName: MoaMapFontName.nanumSquareExtraBold,
        size: 22,
        lineHeight: 22 * 1.3,
        letterSpacing: -0.44
    )
}

/// 운영자가 다는 태그 칩. 시안의 칩 인스턴스가 축소된 크기 그대로다(글자 7.8, 좌우 11.15, 위아래 4.46).
private struct FeaturedTagChip: View {
    @Environment(\.moaColors) private var colors

    let text: String

    var body: some View {
        Text(text)
            .moaTextStyle(Self.style)
            .foregroundStyle(colors.textNormal)
            .lineLimit(1)
            .padding(.horizontal, 11.15)
            .padding(.vertical, 4.46)
            .background(MoaMapPrimitiveColors.white, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 2.79)
    }

    private static let style = MoaMapTextStyle(
        fontName: MoaMapFontName.nanumSquareRegular,
        size: 7.8,
        lineHeight: 7.8 * 1.3,
        letterSpacing: -0.156
    )
}

#Preview {
    FeaturedMapCarousel(maps: FeaturedMap.mocks)
        .padding(.vertical)
        .background(Color(argb: 0xFFE7_F4FB))
}
