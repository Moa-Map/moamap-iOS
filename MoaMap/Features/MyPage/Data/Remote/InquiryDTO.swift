/// 응답은 `{ inquiryId }` 뿐이라 읽지 않는다.
nonisolated struct InquiryRequest: Encodable, Sendable {
    let type: String
    let replyEmail: String
    let content: String
}
