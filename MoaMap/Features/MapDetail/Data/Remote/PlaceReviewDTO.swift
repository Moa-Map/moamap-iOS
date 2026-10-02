import Foundation

nonisolated struct PlaceReviewPageResponse: Decodable, Sendable {
    let content: [PlaceReviewResponse]?
    let last: Bool?
}

nonisolated struct PlaceReviewResponse: Decodable, Sendable {
    let id: Int64
    let userId: Int64?
    let content: String?
    let imageUrls: [String]?
    let createdAt: String?
}

nonisolated struct PlaceReviewCreateRequest: Encodable, Sendable {
    let rating: Int
    let content: String?
    let imageUrls: [String]?
}

nonisolated struct PlaceReviewUpdateRequest: Encodable, Sendable {
    let content: String
}

nonisolated struct PlaceReviewPhotoUploadURLRequest: Encodable, Sendable {
    let contentType: String
    let fileSize: Int
}

nonisolated struct PlaceReviewPhotoUploadURLResponse: Decodable, Sendable {
    let uploadUrl: String?
    let fileUrl: String?
}

nonisolated extension PlaceReviewResponse {
    func toDomain(authorName: String?, timeZone: TimeZone) -> PlaceReview {
        let name = authorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlaceReview(
            id: id,
            authorID: userId ?? 0,
            authorName: name?.isEmpty == false ? name : nil,
            content: content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageURLs: (imageUrls ?? []).compactMap { url in
                url.trimmingCharacters(in: .whitespaces).isEmpty ? nil : URL(string: url)
            },
            createdAt: ServerDateTime.parse(createdAt, timeZone: timeZone)
        )
    }
}

/// 서버 시각은 지역 표시 없이 오는 `LocalDateTime` 이다.
nonisolated enum ServerDateTime {
    /// `2026-07-30T02:54:12`, `...12.123456`, `...12Z`, `...12+09:00` 을 받는다.
    /// 지역 표시가 없으면 `timeZone` 으로 읽는다. 서버와 사용자가 같은 지역에 있다는 전제다.
    static func parse(_ raw: String?, timeZone: TimeZone) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces),
              let match = raw.wholeMatch(of: /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?/)
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        // 관대하게 읽으면 13월 같은 값이 다음 해로 넘어가 조용히 통과한다.
        formatter.isLenient = false
        formatter.timeZone = zone(String(match.2 ?? "")) ?? timeZone
        return formatter.date(from: String(match.1))
    }

    private static func zone(_ designator: String) -> TimeZone? {
        if designator.isEmpty { return nil }
        if designator == "Z" { return TimeZone(identifier: "UTC") }
        let digits = designator.dropFirst().replacingOccurrences(of: ":", with: "")
        guard digits.count == 4, let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)) else { return nil }
        let seconds = (hours * 3600 + minutes * 60) * (designator.hasPrefix("-") ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }
}
