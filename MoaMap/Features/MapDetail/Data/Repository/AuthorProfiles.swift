import Foundation

/// 작성자 닉네임·프로필 사진. 서버가 비워 보낸 값은 nil 이다.
nonisolated struct AuthorProfile: Equatable, Sendable {
    let name: String?
    let imageURL: URL?
}

/// 작성자 식별자로 프로필을 찾는다. 장소 댓글과 게시물 댓글이 같이 쓴다.
@MainActor
enum AuthorProfiles {
    /// 프로필 벌크 조회의 서버 상한.
    static let chunkSize = 100

    /// 곁들이는 정보라 실패를 삼킨다. 이름 한 줄 때문에 목록을 통째로 못 여는 게 더 나쁘다.
    /// 같은 사람이 여러 건을 남길 수 있어 중복을 지우고 묻는다.
    static func fetch(_ authorIDs: [Int64], client: APIClient) async throws -> [Int64: AuthorProfile] {
        var seen = Set<Int64>()
        let ids = authorIDs.filter { $0 > 0 && seen.insert($0).inserted }
        guard !ids.isEmpty else { return [:] }
        do {
            var profiles: [Int64: AuthorProfile] = [:]
            for start in stride(from: 0, to: ids.count, by: chunkSize) {
                let chunk = ids[start..<min(start + chunkSize, ids.count)]
                let request = APIRequest(
                    path: ["api", "v1", "users", "profiles"],
                    queryItems: chunk.map { URLQueryItem(name: "ids", value: String($0)) }
                )
                for response in try await client.send(request, as: [UserProfileResponse].self) {
                    guard let id = response.id else { continue }
                    profiles[id] = response.toAuthorProfile()
                }
            }
            return profiles
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return [:]
        }
    }
}

private nonisolated extension UserProfileResponse {
    func toAuthorProfile() -> AuthorProfile {
        let image = profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AuthorProfile(
            name: nickname.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 },
            imageURL: image.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        )
    }
}
