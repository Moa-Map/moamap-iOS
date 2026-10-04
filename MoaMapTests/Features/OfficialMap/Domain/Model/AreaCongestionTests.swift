import Testing
@testable import MoaMap

private func congestion(ageRates: [AgeGroup: Double] = [:], maleRate: Double? = nil, femaleRate: Double? = nil) -> AreaCongestion {
    AreaCongestion(level: .normal, message: nil, populationMin: nil, populationMax: nil, ageRates: ageRates, maleRate: maleRate, femaleRate: femaleRate)
}

struct AreaCongestionTests {
    @Test func 혼잡도는_서버_문구로_고르고_모르는_문구는_정보_없음이다() {
        #expect(CongestionLevel(label: "약간 붐빔") == .slightlyBusy)
        #expect(CongestionLevel(label: "여유") == .relaxed)
        #expect(CongestionLevel(label: "매우 붐빔") == .unknown)
        #expect(CongestionLevel(label: nil) == .unknown)
    }

    @Test func 비율이_가장_높은_연령대를_고른다() {
        let result = congestion(ageRates: [.twenties: 28.1, .thirties: 31.4, .forties: 12]).dominantAge
        #expect(result == PopulationShare(label: "30대", rate: 31.4))
    }

    @Test func 연령대가_동률이면_더_어린_쪽을_고른다() {
        #expect(congestion(ageRates: [.thirties: 30, .twenties: 30]).dominantAge?.label == "20대")
    }

    @Test func 연령대_정보가_없으면_nil이다() {
        #expect(congestion().dominantAge == nil)
    }

    @Test func 비율이_더_높은_성별을_고르고_동률이면_여성이다() {
        #expect(congestion(maleRate: 54.2, femaleRate: 45.8).dominantGender == PopulationShare(label: "남성", rate: 54.2))
        #expect(congestion(maleRate: 50, femaleRate: 50).dominantGender?.label == "여성")
    }

    @Test func 성별이_한쪽만_있으면_있는_쪽을_고른다() {
        #expect(congestion(maleRate: 60).dominantGender?.label == "남성")
        #expect(congestion(femaleRate: 60).dominantGender?.label == "여성")
        #expect(congestion().dominantGender == nil)
    }
}

struct FootTrafficMapTests {
    @Test func 유동인구_지도는_이름으로_알아본다() {
        #expect(FootTrafficMap.matches(title: "유동인구 지도"))
        #expect(FootTrafficMap.matches(title: " 유동인구 지도 "))
        #expect(!FootTrafficMap.matches(title: "공중화장실 지도"))
    }
}
