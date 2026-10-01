import Foundation
import Observation
import UniformTypeIdentifiers

/// 화면에 들어올 때 한 번 하는 조회. 편집 중인 이름·소개는 따로 들고 있다.
nonisolated enum ProfileLoadState: Equatable, Sendable {
    case loading
    case loaded(email: String, imageURL: URL?)
    case failed(String)
}

/// 사용자가 고른 사진. 저장 전까지 올리지 않는다.
nonisolated struct PickedProfileImage: Equatable, Sendable {
    /// 고를 때마다 바뀐다. 올려 둔 주소가 지금 사진의 것인지 가리는 데 쓴다.
    let selection: Int
    let image: UploadImage
}

nonisolated struct ProfileEditUiState: Equatable, Sendable {
    /// 서버의 `@Size(max = 30)` 과 같은 값.
    static let nicknameMaxLength = 30
    /// 서버 제한을 확인하지 못해 앱에서 먼저 막는다.
    static let introductionMaxLength = 100

    var load: ProfileLoadState = .loading
    var nickname = ""
    var introduction = ""
    var pickedImage: PickedProfileImage?
    var saving = false
    var saved = false
    var errorMessage: String?

    /// 서버가 거절할 것이 뻔한 입력은 보내지 않는다. 앞 공백을 거절하는 규칙이라 길이는 다듬은 뒤로 센다.
    var canSave: Bool {
        guard case .loaded = load, !saving else { return false }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= Self.nicknameMaxLength
    }
}

@MainActor @Observable
final class ProfileEditViewModel {
    static let loadFailedMessage = "프로필을 불러오지 못했어요. 잠시 후 다시 시도해주세요."
    static let saveFailedMessage = "저장하지 못했어요. 잠시 후 다시 시도해주세요."

    private(set) var uiState = ProfileEditUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var saveTask: Task<Void, Never>?
    /// 저장이 끝나 서버가 확정한 프로필.
    private(set) var savedProfile: MyProfile?

    /// 저장이 실패해 다시 눌러도 같은 사진을 두 번 올리지 않게 들고 있다. 올린 파일을 지우는 API 가 없다.
    private var uploaded: (selection: Int, fileURL: String)?
    private var nextSelection = 0
    private let repository: any UserRepository

    init(repository: any UserRepository) { self.repository = repository }

    func load() {
        loadTask?.cancel()
        uiState.load = .loading
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let profile = try await repository.fetchMyProfile()
                try Task.checkCancellation()
                self?.uiState.load = .loaded(email: profile.email, imageURL: profile.profileImageURL)
                self?.uiState.nickname = profile.nickname
                self?.uiState.introduction = profile.introduction
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.load = .failed(Self.loadFailedMessage)
            }
        }
    }

    func updateNickname(_ value: String) {
        uiState.nickname = value
    }

    func updateIntroduction(_ value: String) {
        uiState.introduction = String(value.prefix(ProfileEditUiState.introductionMaxLength))
    }

    /// 저장 중에는 무시한다. 이미 먼저 고른 사진을 올리고 있어, 바꾸면 화면과 저장된 사진이 어긋난다.
    func selectImage(data: Data, type: UTType?) {
        guard !uiState.saving else { return }
        do {
            let image = try UploadImage(pickedData: data, type: type)
            // 저장을 누르기 전에 알린다. 다른 사진을 고르면 되는 일이다.
            try ImageUploadRules.validate(contentType: image.contentType, fileSize: image.fileSize)
            nextSelection += 1
            uiState.pickedImage = PickedProfileImage(selection: nextSelection, image: image)
        } catch {
            uiState.errorMessage = error.userMessage
        }
    }

    func showImageLoadFailure() {
        uiState.errorMessage = ImageUploadError.unreadable.userMessage
    }

    func save() {
        guard uiState.canSave else { return }
        let nickname = uiState.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let introduction = uiState.introduction
        let picked = uiState.pickedImage
        uiState.saving = true
        saveTask = Task { [weak self] in
            guard let self else { return }
            defer { if !Task.isCancelled { self.saveTask = nil } }
            do {
                var imageURL: String?
                if let picked { imageURL = try await resolveImageURL(picked) }
                let profile = try await repository.updateMyProfile(
                    nickname: nickname, introduction: introduction, profileImageURL: imageURL
                )
                try Task.checkCancellation()
                savedProfile = profile
                uiState.saving = false
                uiState.saved = true
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                // 사진을 바꿔야 하는 실패와 다시 누르면 되는 실패를 나눠 안내한다.
                uiState.saving = false
                uiState.errorMessage = (error as? ImageUploadError)?.userMessage ?? Self.saveFailedMessage
            }
        }
    }

    func consumeError() {
        uiState.errorMessage = nil
    }

    private func resolveImageURL(_ picked: PickedProfileImage) async throws -> String {
        if let uploaded, uploaded.selection == picked.selection { return uploaded.fileURL }
        let fileURL = try await repository.uploadProfileImage(picked.image)
        uploaded = (picked.selection, fileURL)
        return fileURL
    }
}
