import SwiftUI

/// 공식지도 목록 카드. 참여는 카드를 눌러 들어간 지도 소개에서 한다.
struct OfficialMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let map: OfficialMap

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MapThumbnail(imageURL: map.imageURL, size: 90)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text(map.title)
                        .moaTextStyle(typography.subtitle2)
                        .foregroundStyle(colors.textNormal)
                        .lineLimit(1)
                    Image("Icons/verified")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("공식 인증")
                }
                .frame(height: 24)
                Text(map.description)
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAlternative)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }
}

#Preview {
    VStack(spacing: 8) {
        OfficialMapCard(map: OfficialMap(id: 6, title: "화장실 위치", description: "공공데이터 기반 공중화장실 위치", imageURL: nil, joined: false))
        OfficialMapCard(map: OfficialMap(id: 7, title: "지도 이름", description: "지도 관련 설명 1줄", imageURL: nil, joined: true))
    }
    .padding()
}
