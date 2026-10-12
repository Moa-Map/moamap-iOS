import Foundation

nonisolated struct EditMapUiState: Equatable, Sendable {
    /// 고치기 전 지도. 바뀐 게 있는지 여기에 견준다.
    let original: MapDetail
    var pickedImage: PickedCoverImage?
    var name: String
    var description: String
    var tags: [String]
    /// 아직 확정되지 않은 태그 입력값.
    var tagInput = ""
    var saving = false
    var saved = false
    var errorMessage: String?

    init(map: MapDetail) {
        original = map
        name = map.title
        description = map.description ?? ""
        tags = map.tags
    }

    /// 입력 중인 태그도 저장할 때 확정되므로 바뀐 것으로 본다.
    /// 서버 값은 앞뒤 공백을 남긴 채 오므로 양쪽 다 다듬어 견준다.
    var hasChanges: Bool {
        pickedImage != nil
            || name.trimmed != original.title.trimmed
            || description.trimmed != (original.description ?? "").trimmed
            || tags != original.tags
            || !tagInput.trimmed.isEmpty
    }

    /// 이름은 서버 필수값이다.
    var canSave: Bool { !name.trimmed.isEmpty && hasChanges && !saving }
}

private extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
