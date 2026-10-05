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
    static let tagMaxLength = 30

    var pickedImage: PickedCoverImage?
    var name = ""
    var description = ""
    var visibility: MapVisibility?
    var tags: [String] = []
    /// 아직 확정되지 않은 태그 입력값.
    var tagInput = ""
    var submit: CreateMapSubmitState = .idle
    var errorMessage: String?

    var isSubmitting: Bool { submit == .submitting }

    /// 이름과 공개 범위는 서버 필수값이다.
    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && visibility != nil && !isSubmitting
    }
}
