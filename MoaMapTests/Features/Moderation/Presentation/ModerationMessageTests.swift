import Foundation
import Testing
@testable import MoaMap

struct ModerationMessageTests {
    @Test(arguments: [
        ("PLACE_019", 409, "이미 신고했어요"),
        ("PLACE_022", 409, "이미 신고했어요"),
        ("MAP_026", 409, "이미 신고했어요"),
        ("USER_025", 409, "이미 신고했어요"),
        ("PLACE_020", 400, "내 콘텐츠는 신고할 수 없어요"),
        ("PLACE_021", 400, "내 콘텐츠는 신고할 수 없어요"),
        ("MAP_025", 400, "내 콘텐츠는 신고할 수 없어요"),
        ("USER_024", 400, "나 자신은 신고할 수 없어요"),
        ("PLACE_002", 403, "볼 수 없는 콘텐츠예요"),
        ("MAP_002", 403, "볼 수 없는 콘텐츠예요"),
        ("MAP_024", 400, "공식 지도는 신고할 수 없어요"),
        ("MAP_018", 404, "이미 삭제된 콘텐츠예요"),
        ("COMMON_005", 500, "신고하지 못했어요. 잠시 후 다시 시도해주세요")
    ])
    func 신고_실패는_코드에_맞는_문구로_바꾼다(code: String, status: Int, message: String) {
        let error = NetworkError.server(code: code, statusCode: status, message: "[\(status)] \(code): 서버 원문")
        #expect(ModerationMessage.reportFailure(error) == message)
    }

    @Test func 연결이_끊기면_네트워크_안내를_띄운다() {
        let error = NetworkError.connection(.notConnectedToInternet)
        #expect(ModerationMessage.reportFailure(error) == "네트워크에 연결할 수 없어요")
        #expect(ModerationMessage.blockFailure(error) == "네트워크에 연결할 수 없어요")
        #expect(ModerationMessage.unblockFailure(error) == "네트워크에 연결할 수 없어요")
    }

    @Test func 차단_실패는_코드에_맞는_문구로_바꾼다() {
        #expect(ModerationMessage.blockFailure(NetworkError.server(code: "USER_026", statusCode: 400)) == "나 자신은 차단할 수 없어요")
        #expect(ModerationMessage.blockFailure(NetworkError.server(code: "USER_003", statusCode: 404)) == "탈퇴했거나 없는 사용자예요")
        #expect(ModerationMessage.blockFailure(NetworkError.decoding) == "차단하지 못했어요. 잠시 후 다시 시도해주세요")
    }

    @Test func 차단_안내는_닉네임이_없으면_사용자로_부른다() {
        #expect(ModerationMessage.blocked(nickname: "모아") == "모아님을 차단했어요")
        #expect(ModerationMessage.blocked(nickname: nil) == "사용자를 차단했어요")
        #expect(ModerationMessage.blocked(nickname: "") == "사용자를 차단했어요")
    }
}
