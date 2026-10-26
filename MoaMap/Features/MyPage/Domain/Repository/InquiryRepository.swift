@MainActor
protocol InquiryRepository {
    /// 최근 24시간에 10건을 넘기면 429 `USER_013`.
    func sendInquiry(type: InquiryType, replyEmail: String, content: String) async throws
}
