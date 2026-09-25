import SwiftUI

struct CommunityMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let map: MapSummary

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MapThumbnail(imageURL: map.imageURL, size: Self.thumbnailSize)

            // 태그 유무와 관계없이 인원·장소 수는 같은 자리에 둔다.
            ZStack(alignment: .bottomTrailing) {
                if map.tags.isEmpty {
                    // 태그가 없으면 이름을 카드 세로 가운데에 둔다.
                    title
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        title
                        MapTagList(tags: Array(map.tags.prefix(3)))
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                stats
                    .padding(.bottom, Self.statsBottomInset)
            }
            .frame(height: Self.thumbnailSize)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    private static let thumbnailSize: CGFloat = 90
    /// 시안에서 인원·장소 수 줄의 아래 끝은 썸네일 아래 끝보다 10.8 위에 있다.
    /// (위 여백 4 + 제목 24 + 간격 4 + 태그 15.6 + 간격 16 + 통계 15.6 = 79.2)
    private static let statsBottomInset: CGFloat = 10.8

    private var title: some View {
        Text(map.title)
            .moaTextStyle(typography.subtitle2)
            .foregroundStyle(colors.textNormal)
            .lineLimit(1)
            .frame(height: 24)
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat(icon: "Icons/person", text: "\(map.memberCount)명")
            if let placeCount = map.placeCount {
                stat(icon: "Icons/location", text: "\(placeCount)곳")
            }
        }
    }

    private func stat(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            Text(text)
                .moaTextStyle(typography.caption0)
        }
        .foregroundStyle(colors.textAssistive)
    }
}

#Preview {
    VStack {
        CommunityMapCard(map: MapSummary(id: 1, title: "지도 이름", imageURL: nil, tags: ["태그", "태그", "태그"], memberCount: 0, placeCount: 0))
        CommunityMapCard(map: MapSummary(id: 2, title: "태그 없는 지도", imageURL: nil, tags: [], memberCount: 0, placeCount: 0))
    }
    .padding()
}
