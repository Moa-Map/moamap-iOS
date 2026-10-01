import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct ProfileEditViewModelTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47])

    private func loaded(_ repository: UserRepositoryStub = UserRepositoryStub()) async -> ProfileEditViewModel {
        let sut = ProfileEditViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        return sut
    }

    @Test func 프로필을_읽어_입력칸을_채운다() async {
        let sut = await loaded()
        #expect(sut.uiState.load == .loaded(email: "moa@example.com", imageURL: nil))
        #expect(sut.uiState.nickname == "모아")
        #expect(sut.uiState.introduction == "안녕")
        #expect(sut.uiState.canSave)
    }

    @Test func 조회에_실패하면_서버_원문_없이_안내하고_다시_읽는다() async {
        let repository = UserRepositoryStub()
        repository.fetch = { throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = await loaded(repository)
        #expect(sut.uiState.load == .failed(ProfileEditViewModel.loadFailedMessage))
        #expect(!sut.uiState.canSave)

        repository.fetch = { UserRepositoryStub.profile }
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.canSave)
    }

    @Test func 이름이_비었거나_다듬어서_30자를_넘으면_저장할_수_없다() async {
        let sut = await loaded()
        sut.updateNickname("   ")
        #expect(!sut.uiState.canSave)
        sut.updateNickname(String(repeating: "가", count: 31))
        #expect(!sut.uiState.canSave)
        sut.updateNickname("  " + String(repeating: "가", count: 30) + " ")
        #expect(sut.uiState.canSave)
    }

    @Test func 자기소개는_100자에서_자른다() async {
        let sut = await loaded()
        sut.updateIntroduction(String(repeating: "a", count: 120))
        #expect(sut.uiState.introduction.count == 100)
    }

    @Test func 사진_없이_저장하면_올리지_않고_이름은_다듬어_보낸다() async {
        let repository = UserRepositoryStub()
        let sut = await loaded(repository)
        sut.updateNickname("  새이름 ")
        sut.save()
        #expect(sut.uiState.saving)
        #expect(!sut.uiState.canSave)
        await sut.saveTask?.value
        #expect(repository.uploads.isEmpty)
        #expect(repository.updates.map(\.nickname) == ["새이름"])
        #expect(repository.updates.first?.imageURL == nil)
        #expect(sut.uiState.saved)
        #expect(sut.savedProfile?.nickname == "새이름")
    }

    @Test func 고른_사진을_올리고_그_주소로_저장한다() async {
        let repository = UserRepositoryStub()
        let sut = await loaded(repository)
        sut.selectImage(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        #expect(repository.uploads == [UploadImage(data: png, contentType: "image/png")])
        #expect(repository.updates.first?.imageURL == "https://cdn.example.com/p.png")
    }

    @Test func 저장이_실패해_다시_눌러도_같은_사진은_한_번만_올린다() async {
        let repository = UserRepositoryStub()
        repository.update = { _, _, _ in throw NetworkError.http(statusCode: 500) }
        let sut = await loaded(repository)
        sut.selectImage(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == ProfileEditViewModel.saveFailedMessage)
        #expect(!sut.uiState.saving)

        repository.update = { nickname, introduction, _ in
            MyProfile(id: 1, nickname: nickname, email: "", profileImageURL: nil, introduction: introduction)
        }
        sut.consumeError()
        sut.save()
        await sut.saveTask?.value
        #expect(repository.uploads.count == 1)
        #expect(sut.uiState.saved)
    }

    @Test func 다른_사진을_고르면_다시_올린다() async {
        let repository = UserRepositoryStub()
        repository.update = { _, _, _ in throw NetworkError.http(statusCode: 500) }
        let sut = await loaded(repository)
        sut.selectImage(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        sut.selectImage(data: Data([1, 2]), type: .jpeg)
        sut.save()
        await sut.saveTask?.value
        #expect(repository.uploads.count == 2)
    }

    @Test func 너무_큰_사진은_고를_때_막는다() async {
        let sut = await loaded()
        sut.selectImage(data: Data(count: ImageUploadRules.maxImageFileSize + 1), type: .jpeg)
        #expect(sut.uiState.pickedImage == nil)
        #expect(sut.uiState.errorMessage == "사진 크기는 10MB 이하여야 해요")
    }

    @Test func 읽을_수_없는_사진은_안내한다() async {
        let sut = await loaded()
        sut.selectImage(data: Data("x".utf8), type: .heic)
        #expect(sut.uiState.pickedImage == nil)
        #expect(sut.uiState.errorMessage == "사진을 불러오지 못했어요")
    }

    @Test func 업로드_실패는_사진_문제로_안내한다() async {
        let repository = UserRepositoryStub()
        repository.upload = { _ in throw ImageUploadError.unsupportedType }
        let sut = await loaded(repository)
        sut.selectImage(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == "JPG, PNG, WEBP 형식만 올릴 수 있어요")
        #expect(repository.updates.isEmpty)
    }

    @Test func 저장_중에는_사진을_바꾸지_않는다() async {
        let repository = UserRepositoryStub()
        let release = AsyncGate()
        repository.update = { nickname, introduction, _ in
            await release.wait()
            return MyProfile(id: 1, nickname: nickname, email: "", profileImageURL: nil, introduction: introduction)
        }
        let sut = await loaded(repository)
        sut.selectImage(data: png, type: .png)
        let picked = sut.uiState.pickedImage
        sut.save()
        sut.selectImage(data: Data([9]), type: .jpeg)
        #expect(sut.uiState.pickedImage == picked)
        await release.open()
        await sut.saveTask?.value
    }
}
