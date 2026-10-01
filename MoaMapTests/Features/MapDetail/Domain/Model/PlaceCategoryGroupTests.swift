import Testing
@testable import MoaMap

struct PlaceCategoryGroupTests {
    @Test(arguments: [
        ("가정,생활 > 대형마트 > 이마트", PlaceCategoryGroup.mart),
        ("가정,생활 > 슈퍼마켓", .mart),
        ("가정,생활 > 편의점 > GS25", .convenienceStore),
        ("교육,학문 > 유아교육 > 어린이집", .childcare),
        ("교육,학문 > 학교 > 대학교", .school),
        ("교육,학문 > 학원 > 외국어학원", .academy),
        ("교통,수송 > 교통시설 > 주차장 > 공영주차장", .parking),
        ("교통,수송 > 자동차 > 주유,가스 > GS칼텍스", .gasStation),
        ("교통,수송 > 지하철,전철 > 수도권2호선", .subway),
        ("금융,보험 > 금융서비스 > 은행", .bank),
        ("문화,예술 > 문화시설 > 미술관", .culture),
        ("문화,예술 > 영화,영상 > 영화관", .culture),
        ("부동산 > 부동산서비스 > 부동산중개", .realEstate),
        ("사회,공공기관 > 행정기관", .publicOffice),
        ("여행 > 관광,명소 > 궁", .attraction),
        ("여행 > 숙박 > 호텔", .lodging),
        ("음식점 > 한식", .restaurant),
        ("음식점 > 카페 > 커피전문점", .cafe),
        ("의료,건강 > 병원 > 내과", .hospital),
        ("의료,건강 > 약국", .pharmacy)
    ])
    func 실제_경로가_해당_그룹으로_간다(path: String, group: PlaceCategoryGroup) {
        #expect(PlaceCategoryGroup(categoryPath: path) == group)
    }

    @Test func 주차장_주유소는_셋째_토막까지_맞아야_한다() {
        #expect(PlaceCategoryGroup(categoryPath: "교통,수송 > 교통시설 > 버스정류장") == nil)
        #expect(PlaceCategoryGroup(categoryPath: "교통,수송 > 자동차 > 정비소") == nil)
    }

    @Test func 토막_앞뒤_공백이_달라도_같은_경로로_본다() {
        #expect(PlaceCategoryGroup(categoryPath: "음식점>카페 >  커피전문점") == .cafe)
    }

    @Test(arguments: ["", "쇼핑 > 패션", "스포츠,레저 > 골프"])
    func 어느_그룹에도_들지_않으면_nil(path: String) {
        #expect(PlaceCategoryGroup(categoryPath: path) == nil)
    }
}
