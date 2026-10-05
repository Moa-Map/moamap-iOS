import Foundation

/// 지역 카드 통계 한 칸. 라벨은 가장 많은 연령대·성별에 따라 바뀐다.
nonisolated struct AreaStat: Equatable, Sendable {
    let label: String
    let value: String

    static func stats(for congestion: AreaCongestion?) -> [AreaStat] {
        guard let congestion else { return [] }
        var stats: [AreaStat] = []
        if let count = congestion.populationMin {
            stats.append(AreaStat(label: "인구", value: population(count)))
        }
        if let age = congestion.dominantAge {
            stats.append(AreaStat(label: "\(age.label) 비율", value: "\(Int(age.rate.rounded()))%"))
        }
        if let gender = congestion.dominantGender {
            stats.append(AreaStat(label: "\(gender.label) 비율", value: "\(Int(gender.rate.rounded()))%"))
        }
        return stats
    }

    /// 100명대 지역도 있어 1만 미만은 명 단위로 쓴다. 그 이상은 만 단위로 줄이되 소수 한 자리를 남긴다.
    private static func population(_ count: Int64) -> String {
        guard count >= 10_000 else {
            return "약 \(count.formatted(.number.locale(Locale(identifier: "ko_KR"))))명"
        }
        let tenThousands = Double(count) / 10_000
        let text = tenThousands.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "ko_KR")))
        return "약 \(text)만 명"
    }
}
