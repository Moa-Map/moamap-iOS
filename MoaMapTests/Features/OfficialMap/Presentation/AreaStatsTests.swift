import Testing
@testable import MoaMap

private func congestion(populationMin: Int64? = nil, ageRates: [AgeGroup: Double] = [:], maleRate: Double? = nil, femaleRate: Double? = nil) -> AreaCongestion {
    AreaCongestion(level: .normal, message: nil, populationMin: populationMin, populationMax: nil, ageRates: ageRates, maleRate: maleRate, femaleRate: femaleRate)
}

struct AreaStatsTests {
    @Test func 인구와_최다_연령대_성별을_세_칸으로_만든다() {
        let stats = AreaStat.stats(for: congestion(populationMin: 32_000, ageRates: [.twenties: 31.6], maleRate: 44, femaleRate: 56))
        #expect(stats == [
            AreaStat(label: "인구", value: "약 3.2만 명"),
            AreaStat(label: "20대 비율", value: "32%"),
            AreaStat(label: "여성 비율", value: "56%")
        ])
    }

    @Test func 일만_명_미만은_명_단위로_쓴다() {
        #expect(AreaStat.stats(for: congestion(populationMin: 9_500)).first?.value == "약 9,500명")
        #expect(AreaStat.stats(for: congestion(populationMin: 100)).first?.value == "약 100명")
    }

    @Test func 일만_명_이상은_만_단위로_줄이되_자투리를_남긴다() {
        #expect(AreaStat.stats(for: congestion(populationMin: 16_000)).first?.value == "약 1.6만 명")
        #expect(AreaStat.stats(for: congestion(populationMin: 120_000)).first?.value == "약 12만 명")
    }

    @Test func 값이_없는_칸은_빠지고_혼잡도가_없으면_비어_있다() {
        #expect(AreaStat.stats(for: congestion(femaleRate: 56)) == [AreaStat(label: "여성 비율", value: "56%")])
        #expect(AreaStat.stats(for: nil).isEmpty)
    }
}
