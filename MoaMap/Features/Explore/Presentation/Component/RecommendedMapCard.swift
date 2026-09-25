import SwiftUI

struct RecommendedMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let map: MapSummary

    var body: some View {
        HStack(spacing: 16) {
            MapThumbnail(imageURL: map.imageURL, size: 65)

            VStack(alignment: .leading, spacing: 12) {
                Text(map.title)
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(1)
                // 태그가 없으면 줄 간격까지 빼서 이름이 카드 세로 가운데에 오게 한다.
                if !map.tags.isEmpty {
                    MapTagList(tags: Array(map.tags.prefix(2)))
                }
            }
            .frame(width: 115, alignment: .leading)
        }
        .padding(12)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }
}

#Preview {
    RecommendedMapCard(map: MapSummary(id: 1, title: "지도 이름", imageURL: nil, tags: ["태그", "태그"], memberCount: 0, placeCount: 0))
        .padding()
}
