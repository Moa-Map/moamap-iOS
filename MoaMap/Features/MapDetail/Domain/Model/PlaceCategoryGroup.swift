import Foundation

/// 카카오 카테고리 그룹. 마커 아이콘이 이 기준을 쓴다.
///
/// 서버가 그룹 코드 없이 분류 경로만 내려줘 경로 앞부분으로 그룹을 되짚는다.
nonisolated enum PlaceCategoryGroup: CaseIterable, Sendable {
    case mart, convenienceStore, childcare, school, academy, parking, gasStation, subway, bank
    case culture, realEstate, publicOffice, attraction, lodging, restaurant, cafe, hospital, pharmacy

    /// 위에서부터 처음 맞는 줄을 쓴다. 카페는 `음식점 > 카페` 로 시작해 음식점보다 먼저 본다.
    private static let pathRules: [([String], PlaceCategoryGroup)] = [
        (["음식점", "카페"], .cafe),
        (["음식점"], .restaurant),
        (["가정,생활", "대형마트"], .mart),
        (["가정,생활", "슈퍼마켓"], .mart),
        (["가정,생활", "편의점"], .convenienceStore),
        (["교육,학문", "유아교육"], .childcare),
        (["교육,학문", "학교"], .school),
        (["교육,학문", "학원"], .academy),
        (["교통,수송", "교통시설", "주차장"], .parking),
        (["교통,수송", "자동차", "주유,가스"], .gasStation),
        (["교통,수송", "지하철,전철"], .subway),
        (["금융,보험", "금융서비스"], .bank),
        (["문화,예술", "문화시설"], .culture),
        (["문화,예술", "영화,영상"], .culture),
        (["부동산", "부동산서비스"], .realEstate),
        (["사회,공공기관"], .publicOffice),
        (["여행", "관광,명소"], .attraction),
        (["여행", "숙박"], .lodging),
        (["의료,건강", "병원"], .hospital),
        (["의료,건강", "약국"], .pharmacy)
    ]

    /// `"음식점 > 카페 > 커피전문점"` 같은 경로가 속한 그룹. 어디에도 들지 않으면 nil.
    init?(categoryPath: String) {
        let segments = categoryPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let rule = Self.pathRules.first(where: { prefix, _ in segments.starts(with: prefix) }) else {
            return nil
        }
        self = rule.1
    }
}
