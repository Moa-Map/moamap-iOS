import SwiftUI

/// 지도 대표 이미지. 이미지가 없거나 불러오지 못하면 기본 이미지를 보여준다.
struct MapThumbnail: View {
    @Environment(\.moaColors) private var colors

    var imageURL: URL?
    let size: CGFloat

    var body: some View {
        RemoteImage(url: imageURL)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(colors.lineAlternative, lineWidth: 1)
            }
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
