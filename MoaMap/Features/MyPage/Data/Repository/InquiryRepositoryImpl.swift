import Foundation

@MainActor
final class InquiryRepositoryImpl: InquiryRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    /// 서버는 공백을 떼기 전에 이메일 형식을 검사해, 공백이 붙어 있으면 400 이다.
    func sendInquiry(type: InquiryType, replyEmail: String, content: String) async throws {
        let body = InquiryRequest(
            type: type.rawValue,
            replyEmail: replyEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let request = APIRequest(path: ["api", "v1", "inquiries"], method: .post, jsonBody: try JSONEncoder().encode(body))
        try await client.sendWithoutResponse(request)
    }
}
