/// 추가할 장소를 찾는다. 서버에 검색 API 가 생기면 구현체만 바꾼다.
@MainActor
protocol PlaceSearchRepository {
    /// 등록할 수 없는 결과(좌표나 id 가 없는 항목)는 걸러서 돌려준다.
    func search(query: String) async throws -> [PlaceCandidate]
}
