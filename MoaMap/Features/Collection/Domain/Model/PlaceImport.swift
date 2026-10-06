import Foundation

/// 장소를 어디서 가져오는지. 흐름과 화면은 같고 부르는 API 와 안내 문구만 갈린다.
nonisolated enum PlaceImportSource: Equatable, Sendable {
    /// 릴스 링크. 앱이 캡션을 읽어 서버에 넘긴다.
    case instagram
    /// 네이버·카카오·구글 지도의 리스트 공유 링크. 서버가 직접 읽는다.
    case mapShare
}

/// 링크에서 뽑아낸 장소 후보. 후보를 다시 조회하지 않으므로 등록에 필요한 값을 전부 들고 있다.
nonisolated struct ImportedPlace: Identifiable, Equatable, Sendable {
    /// 서버 응답에 고유 id 가 없어 `kakaoPlaceID` 를 쓰고, 없으면 순번으로 채운다.
    let id: String
    let name: String
    /// 지번 주소.
    var address: String?
    var roadAddress: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var category: String?
    /// 공유 리스트에 사용자가 적어 둔 메모.
    var description: String?
    var kakaoPlaceID: String?
    /// `INSTAGRAM`, `NAVER_MAP`, `KAKAO_MAP`, `GOOGLE_MAP`.
    var sourceType = ""
    var sourceURL: String?

    /// 도로명을 먼저 쓰고 없으면 지번으로 대체한다.
    var displayAddress: String {
        if let roadAddress, !roadAddress.trimmingCharacters(in: .whitespaces).isEmpty { return roadAddress }
        return address ?? ""
    }

    /// 서버가 `kakaoPlaceId` 를 필수로 요구해 없는 후보는 고를 수 없다.
    var savable: Bool {
        kakaoPlaceID.map { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? false
    }
}

/// 등록 전에 장소마다 덧붙이는 값.
nonisolated struct PlaceEdit: Equatable, Sendable {
    var tags: [String] = []
    var memo = ""
    var photos: [UploadImage] = []

    var isEmpty: Bool {
        tags.isEmpty && memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photos.isEmpty
    }
}

/// 등록 직전의 장소 한 건. 추출 결과와 편집값이 어긋나지 않게 한 덩어리로 넘긴다.
nonisolated struct EditedPlace: Equatable, Sendable {
    let place: ImportedPlace
    let edit: PlaceEdit
}

/// 일괄 등록 결과. 서버가 건별로 부분 성공시키고, 여러 지도면 모두 합산한다.
nonisolated struct PlaceSaveResult: Equatable, Sendable {
    let created: Int
    /// 그 지도에 이미 있던 장소.
    let duplicate: Int
    let failed: Int
}

/// 인스타그램 캡션을 읽지 못한 이유. 사용자가 조치할 수 있어 문구를 그대로 보여준다.
nonisolated enum PlaceExtractionError: Error, Equatable, Sendable {
    /// 비공개 계정이거나 로그인이 필요한 게시물.
    case captionBlocked
    /// 링크가 잘못됐거나 게시물을 읽지 못했다.
    case captionUnavailable
    /// 인스타그램에 닿지 못했다. 링크를 확인하라고 하면 엉뚱한 조치를 하게 된다.
    case captionNetwork

    var userMessage: String {
        switch self {
        case .captionBlocked: "비공개 게시물이라 장소를 가져올 수 없어요"
        case .captionUnavailable: "링크를 다시 확인해주세요"
        case .captionNetwork: "네트워크에 연결할 수 없어요"
        }
    }
}
