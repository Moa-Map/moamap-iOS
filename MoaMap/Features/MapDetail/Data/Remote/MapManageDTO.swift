import Foundation

nonisolated struct PlaceActivityPageResponse: Decodable, Sendable {
    let content: [PlaceActivityResponse]?
}

nonisolated struct PlaceActivityResponse: Decodable, Sendable {
    let type: String?
    let occurredAt: String?
    let actorNickname: String?
    let actorProfileImageUrl: String?
    let placeId: Int64?
    let placeName: String?

    /// 모르는 종류는 버린다.
    func toDomain(timeZone: TimeZone) -> MapActivity? {
        let activityType: MapActivityType
        switch type {
        case "PLACE_ADDED": activityType = .placeAdded
        case "PLACE_DELETED": activityType = .placeRemoved
        case "REVIEW_CREATED": activityType = .reviewCreated
        default: return nil
        }
        return MapActivity(
            type: activityType,
            occurredAt: ServerDateTime.parse(occurredAt, timeZone: timeZone),
            // 서버는 이름을 못 찾으면 "알 수 없음" 을 넣는다. 비워 둔 것과 같이 다뤄 문구는 화면이 정한다.
            actorName: actorNickname.trimmedNonEmpty,
            actorImageURL: actorProfileImageUrl.trimmedNonEmpty.flatMap(URL.init(string:)),
            placeID: placeId,
            placeName: placeName.trimmedNonEmpty
        )
    }
}

nonisolated struct PendingPlacePageResponse: Decodable, Sendable {
    let content: [PendingPlaceResponse]?
    let last: Bool?
}

nonisolated struct PendingPlaceResponse: Decodable, Sendable {
    let id: Int64
    let name: String?
    let createdByNickname: String?
    let createdByProfileImageUrl: String?
    let createdAt: String?

    func toDomain(timeZone: TimeZone) -> PendingPlace {
        PendingPlace(
            id: id,
            placeName: name.trimmedNonEmpty,
            requesterName: createdByNickname.trimmedNonEmpty,
            requesterImageURL: createdByProfileImageUrl.trimmedNonEmpty.flatMap(URL.init(string:)),
            requestedAt: ServerDateTime.parse(createdAt, timeZone: timeZone)
        )
    }
}

private nonisolated extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
