import SwiftUI

/// 지도에서 고른 지역의 혼잡도 카드.
struct AreaInfoCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let area: DensityArea

    private var level: CongestionLevel { area.congestion?.level ?? .unknown }

    var body: some View {
        let stats = AreaStat.stats(for: area.congestion)
        VStack(alignment: .leading, spacing: 12) {
            header
            if !stats.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(stats, id: \.label) { stat in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.label)
                                .moaTextStyle(typography.caption0)
                            Text(stat.value)
                                .moaTextStyle(typography.body3)
                        }
                        .foregroundStyle(colors.textAlternative)
                        .lineLimit(1)
                    }
                }
            }
            if let message = area.congestion?.message, !message.isEmpty {
                Text(message)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textAssistive)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(area.name)
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textNormal)
                .lineLimit(1)
            // 이름이 길어도 태그는 밀려나지 않는다.
            Text(level.label)
                .moaTextStyle(typography.caption0)
                .foregroundStyle(level.tagColors.content)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(level.tagColors.background, in: Capsule())
                .overlay { Capsule().strokeBorder(level.tagColors.border, lineWidth: 1) }
                .fixedSize()
        }
    }
}

#Preview {
    AreaInfoCard(area: DensityArea(
        code: "POI038", name: "신도림역", latitude: 37.509, longitude: 126.890, boundary: nil,
        congestion: AreaCongestion(
            level: .busy, message: "사람이 몰려 있을 수 있어요. 인구밀도가 높은 구간에서는 도보 이동시 부딪힘에 주의하세요.",
            populationMin: 32_000, populationMax: 34_000, ageRates: [.twenties: 31.6], maleRate: 44, femaleRate: 56
        )
    ))
    .padding()
    .background(MoaMapPrimitiveColors.backgroundSecondary)
}
