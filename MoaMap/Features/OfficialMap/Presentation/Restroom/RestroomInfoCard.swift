import SwiftUI

/// 마커를 눌렀을 때 아래에 뜨는 화장실 정보. 이름·분류는 마커에 이미 있어 바로 그리고, 나머지는 상세를 받아 채운다.
struct RestroomInfoCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let restroom: RestroomMarker
    let detail: RestroomDetailState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(restroom.name)
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(1)
                if let category = restroom.category {
                    // 이름이 길어도 분류는 밀려나지 않는다.
                    Text(category)
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textAssistive)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            switch detail {
            case .loaded(let detail):
                rows(detail)
            case .failed:
                message("정보를 불러오지 못했어요. 화장실을 다시 누르면 다시 불러와요")
            case .loading, nil:
                message("정보를 불러오는 중이에요")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    private func rows(_ detail: RestroomDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(detail.infoRows, id: \.label) { row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label)
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textAssistive)
                        .frame(width: 56, alignment: .leading)
                    Text(row.value)
                        .moaTextStyle(typography.body3)
                        .foregroundStyle(colors.textAlternative)
                }
            }
            if let date = detail.dataRefDate {
                Text("\(date.replacingOccurrences(of: "-", with: ".")) 기준 공공데이터")
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textAssistive)
                    .padding(.top, 4)
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .moaTextStyle(typography.body3)
            .foregroundStyle(colors.textAssistive)
    }
}

#Preview {
    VStack(spacing: 12) {
        RestroomInfoCard(
            restroom: RestroomMarker(id: 1, name: "시청역", latitude: 0, longitude: 0, category: "공중화장실"),
            detail: .loaded(RestroomDetail(
                id: 1, name: "시청역", category: "공중화장실", address: "서울특별시 중구 세종대로 지하 101",
                openHours: "정시", openHoursDetail: "05:00~24:00", maleToilet: 6, maleUrinal: 5, maleDisabledToilet: 1,
                maleDisabledUrinal: 0, maleChildToilet: 0, maleChildUrinal: 0, femaleToilet: 15, femaleDisabledToilet: 1,
                femaleChildToilet: 0, diaperTable: true, emergencyBell: true, entranceCctv: true,
                managerOrg: "서울교통공사", phone: "02-6110-1321", dataRefDate: "2026-09-01"
            ))
        )
        RestroomInfoCard(restroom: RestroomMarker(id: 2, name: "명달근린공원", latitude: 0, longitude: 0, category: nil), detail: .loading)
    }
    .padding()
    .background(MoaMapPrimitiveColors.backgroundSecondary)
}
