import SwiftUI

/// 공식지도 목록 카드. 참여는 카드를 눌러 들어간 지도 소개에서 한다.
///
/// 설명은 두 줄까지, 비면 줄을 두지 않는다. 장소 수는 0 이어도 보인다.
struct OfficialMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let map: OfficialMap

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MapThumbnail(imageURL: map.imageURL, size: 80)
            VStack(alignment: .trailing, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 2) {
                        Text(map.title)
                            .moaTextStyle(typography.subtitle2)
                            .foregroundStyle(colors.textNormal)
                            .lineLimit(1)
                        Image("Icons/verified")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .accessibilityLabel("공식 인증")
                    }
                    if !map.description.isEmpty {
                        Text(map.description)
                            .moaTextStyle(typography.caption0)
                            .foregroundStyle(colors.textNormal)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                placeCount
            }
            .padding(.vertical, 2)
            .frame(height: 80)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    private var placeCount: some View {
        HStack(spacing: 2) {
            Image("Icons/location").renderingMode(.template).resizable()
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            Text("\(map.placeCount)곳").moaTextStyle(typography.caption0)
        }
        .foregroundStyle(colors.textAssistive)
    }
}

#Preview {
    VStack(spacing: 8) {
        OfficialMapCard(map: OfficialMap(id: 6, title: "화장실 위치", description: "공공데이터 기반 공중화장실 위치", imageURL: nil, joined: false))
        OfficialMapCard(map: OfficialMap(id: 7, title: "지도 이름", description: "지도 관련 설명 1줄", imageURL: nil, joined: true, placeCount: 12))
    }
    .padding()
}
