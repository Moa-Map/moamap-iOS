import SwiftUI

/// 홈의 공식 지도 카드. 시안 「탐색탭_지도」: 여백 12, 사진 110 ↔ 이름 8, 이름은 위아래 2 안쪽.
///
/// 설명은 없고 이름만 사진 폭 안에서 두 줄까지, 넘치면 「…」. 한 줄 이름도 두 줄 자리를 잡아
/// 가로 목록의 카드 높이를 맞춘다.
struct HomeOfficialMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let map: OfficialMap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MapThumbnail(imageURL: map.imageURL, size: Self.imageSize)
            Text(map.title)
                .moaTextStyle(typography.body3)
                .foregroundStyle(colors.textNormal)
                .lineLimit(2, reservesSpace: true)
                .padding(.vertical, 2)
                .frame(width: Self.imageSize, alignment: .leading)
        }
        .padding(12)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    private static let imageSize: CGFloat = 110
}

#Preview {
    HStack(spacing: 8) {
        HomeOfficialMapCard(map: OfficialMap(id: 1, title: "공중화장실 지도", description: "행정안전부 공공데이터 기반", imageURL: nil, joined: false))
        HomeOfficialMapCard(map: OfficialMap(id: 2, title: "유동인구 지도", description: "", imageURL: nil, joined: true))
    }
    .padding()
}
