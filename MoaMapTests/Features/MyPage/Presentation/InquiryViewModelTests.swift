import Foundation
import Testing
@testable import MoaMap

@MainActor
struct InquiryViewModelTests {
    private func filled(_ repository: InquiryRepositoryStub = InquiryRepositoryStub()) -> InquiryViewModel {
        let sut = InquiryViewModel(repository: repository, userRepository: UserRepositoryStub())
        sut.selectType(.technical)
        sut.updateEmail("me@moa.com")
        sut.updateContent("앱이 멈춰요")
        return sut
    }

    @Test func 계정_이메일로_한_번_채운다() async {
        let sut = InquiryViewModel(repository: InquiryRepositoryStub(), userRepository: UserRepositoryStub())
        sut.prefillEmail()
        await sut.prefillTask?.value
        #expect(sut.uiState.email == "moa@example.com")
    }

    @Test func 먼저_적었거나_지웠으면_늦게_온_계정_이메일로_덮지_않는다() async {
        let users = UserRepositoryStub()
        let gate = AsyncStream<Void>.makeStream()
        users.fetch = {
            for await _ in gate.stream { break }
            return UserRepositoryStub.profile
        }
        let sut = InquiryViewModel(repository: InquiryRepositoryStub(), userRepository: users)
        sut.prefillEmail()
        sut.updateEmail("a")
        sut.updateEmail("")
        gate.continuation.yield()
        await sut.prefillTask?.value
        #expect(sut.uiState.email == "")
    }

    @Test func 계정_이메일을_못_받으면_빈칸으로_둔다() async {
        let users = UserRepositoryStub()
        users.fetch = { throw NetworkError.http(statusCode: 500) }
        let sut = InquiryViewModel(repository: InquiryRepositoryStub(), userRepository: users)
        sut.prefillEmail()
        await sut.prefillTask?.value
        #expect(sut.uiState.email == "")
    }

    @Test(arguments: [
        ("me@moa.com", true), (" me@moa.com ", true), ("me@moa", false), ("me moa@x.com", false),
        ("@moa.com", false), ("me@@moa.com", false), ("me@moa.", false), ("", false)
    ])
    func 이메일_모양을_서버와_같게_본다(email: String, expected: Bool) {
        #expect(InquiryForm.isEmailShaped(email) == expected)
    }

    @Test func 유형_이메일_내용을_다_채워야_보낼_수_있다() {
        let sut = InquiryViewModel(repository: InquiryRepositoryStub(), userRepository: UserRepositoryStub())
        #expect(!sut.uiState.canSubmit)
        sut.selectType(.other)
        sut.updateEmail("me@moa.com")
        #expect(!sut.uiState.canSubmit)
        sut.updateContent("  \n ")
        #expect(!sut.uiState.canSubmit)
        sut.updateContent("문의")
        #expect(sut.uiState.canSubmit)
    }

    @Test func 길이를_서버_한도에서_자른다() {
        let sut = InquiryViewModel(repository: InquiryRepositoryStub(), userRepository: UserRepositoryStub())
        sut.updateEmail(String(repeating: "a", count: 300))
        sut.updateContent(String(repeating: "가", count: 2100))
        #expect(sut.uiState.email.count == 254)
        #expect(sut.uiState.content.count == 2000)
    }

    @Test func 두_번_눌러도_한_번만_보내고_접수되면_알린다() async {
        let repository = InquiryRepositoryStub()
        let sut = filled(repository)
        sut.submit()
        #expect(sut.uiState.submitting)
        #expect(!sut.uiState.canSubmit)
        sut.submit()
        await sut.submitTask?.value
        #expect(repository.sent.count == 1)
        #expect(repository.sent.first?.type == .technical)
        #expect(repository.sent.first?.replyEmail == "me@moa.com")
        #expect(sut.uiState.submitted)
        #expect(!sut.uiState.submitting)
    }

    @Test func 하루_한도를_넘기면_서버_안내를_그대로_보여_준다() async {
        let repository = InquiryRepositoryStub()
        repository.send = { throw NetworkError.server(code: "USER_013", statusCode: 429, message: "하루에 10건까지 보낼 수 있어요.") }
        let sut = filled(repository)
        sut.submit()
        await sut.submitTask?.value
        #expect(sut.uiState.errorMessage == "하루에 10건까지 보낼 수 있어요.")
        #expect(!sut.uiState.submitted)
        #expect(sut.uiState.canSubmit)
    }

    @Test func 그_밖의_실패는_원문_없이_안내한다() async {
        let repository = InquiryRepositoryStub()
        repository.send = { throw NetworkError.server(code: "COMMON_001", statusCode: 400, message: "원문") }
        let sut = filled(repository)
        sut.submit()
        await sut.submitTask?.value
        #expect(sut.uiState.errorMessage == "문의를 보내지 못했어요")
        sut.consumeError()
        #expect(sut.uiState.errorMessage == nil)
    }
}
