import SwiftUI

/// 홈의 공식 지도 카드. 시안: 여백 12, 사진 120(모서리 12) ↔ 글 16, 이름 줄 24 ↔ 설명 4.
///
/// 이름과 설명은 사진 폭 안에서 한 줄로, 넘치면 「…」.
struct HomeOfficialMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let map: OfficialMap

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MapThumbnail(imageURL: map.imageURL, size: Self.imageSize)
            VStack(alignment: .leading, spacing: 4) {
                Text(map.title)
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(1)
                    .frame(height: 24)
                // 설명이 비어도 줄은 남긴다. 카드 높이가 달라지면 가로 목록이 들쭉날쭉해진다.
                Text(map.description.isEmpty ? " " : map.description)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(MoaMapPrimitiveColors.blue800)
                    .lineLimit(1)
            }
            .frame(width: Self.imageSize, alignment: .leading)
        }
        .padding(12)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    private static let imageSize: CGFloat = 120
}

#Preview {
    HStack(spacing: 12) {
        HomeOfficialMapCard(map: OfficialMap(id: 1, title: "공중화장실 지도", description: "행정안전부 공공데이터 기반", imageURL: nil, joined: false))
        HomeOfficialMapCard(map: OfficialMap(id: 2, title: "유동인구 지도", description: "", imageURL: nil, joined: true))
    }
    .padding()
}
