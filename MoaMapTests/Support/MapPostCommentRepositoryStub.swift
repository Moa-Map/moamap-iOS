import Foundation
@testable import MoaMap

@MainActor
final class MapPostCommentRepositoryStub: MapPostCommentRepository {
    var comments: (Int64) async throws -> [MapPostComment] = { _ in [] }
    var create: (String) async throws -> MapPostComment = { content in .fixture(id: 99, authorID: 1, content: content) }
    private(set) var fetchCalls: [Int64] = []
    var delete: (Int64) async throws -> Void = { _ in }
    private(set) var sent: [String] = []
    private(set) var deleted: [Int64] = []

    func fetchComments(mapID: Int64, postID: Int64) async throws -> [MapPostComment] {
        fetchCalls.append(postID)
        return try await comments(postID)
    }

    func createComment(mapID: Int64, postID: Int64, content: String) async throws -> MapPostComment {
        sent.append(content)
        return try await create(content)
    }

    func deleteComment(mapID: Int64, postID: Int64, commentID: Int64) async throws {
        deleted.append(commentID)
        try await delete(commentID)
    }
}

extension MapPostComment {
    static func fixture(id: Int64, authorID: Int64 = 2, content: String = "댓글") -> MapPostComment {
        MapPostComment(id: id, authorID: authorID, authorName: "모아", authorImageURL: nil, content: content, createdAt: nil)
    }
}
