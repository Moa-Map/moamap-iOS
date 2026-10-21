import Foundation

nonisolated enum CreateMapSubmitState: Equatable, Sendable {
    case idle
    case submitting
    /// 프라이빗 지도라 초대 코드를 보여줄 차례다. 지도는 이미 만들어졌다.
    case showingInviteCode(mapID: Int64, inviteCode: String)
    case done(mapID: Int64)
}

/// 고른 커버 사진. 제출할 때 올린다.
nonisolated struct PickedCoverImage: Equatable, Sendable {
    /// 고를 때마다 바뀐다. 올려 둔 주소가 지금 사진의 것인지 가리는 데 쓴다.
    let selection: Int
    let image: UploadImage
}

nonisolated struct CreateMapUiState: Equatable, Sendable {
    /// 서버 `MapCreateRequest` 의 `@Size` 제약.
    static let nameMaxLength = 100
    static let descriptionMaxLength = 500

    var pickedImage: PickedCoverImage?
    var name = ""
    var description = ""
    var visibility: MapVisibility?
    var tags: [String] = []
    /// 아직 확정되지 않은 태그 입력값.
    var tagInput = ""
    /// 외부 지도에서 불러와 지도를 만들 때 함께 넣을 장소. 다시 불러오면 바뀐다.
    var importedPlaces: [EditedPlace] = []
    var submit: CreateMapSubmitState = .idle
    var errorMessage: String?
    /// 지도는 만들었지만 장소를 다 넣지 못했다. 만들기 화면을 닫은 뒤 보여준다.
    var placeSaveNotice: String?

    var isSubmitting: Bool { submit == .submitting }

    /// 이름과 공개 범위는 서버 필수값이다.
    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && visibility != nil && !isSubmitting
    }
}
