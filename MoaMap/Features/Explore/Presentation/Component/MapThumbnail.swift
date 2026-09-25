import SwiftUI

/// 지도 대표 이미지. 이미지가 없거나 불러오지 못하면 기본 썸네일을 보여준다.
struct MapThumbnail: View {
    var imageURL: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            MoaMapPrimitiveColors.blue50
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.black.opacity(0.2), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image("map-thumbnail-placeholder")
            .resizable()
            .scaledToFit()
            // 시안의 좌우 여백 24 에 테두리 1 을 더한 값.
            .padding(.horizontal, 25)
    }
}

/// `# 태그` 형식의 한 줄 태그 목록.
struct MapTagList: View {
    @Environment(\.moaTypography) private var typography

    let tags: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                Text("# \(tag)")
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(MoaMapPrimitiveColors.blue800)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    VStack {
        MapThumbnail(size: 90)
        MapThumbnail(size: 65)
        MapTagList(tags: ["맛집", "데이트코스"])
    }
}
