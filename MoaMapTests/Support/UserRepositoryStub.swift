import Foundation
@testable import MoaMap

@MainActor
final class UserRepositoryStub: UserRepository {
    nonisolated static let profile = MyProfile(id: 1, nickname: "모아", email: "moa@example.com", profileImageURL: nil, introduction: "안녕")

    var fetch: () async throws -> MyProfile = { UserRepositoryStub.profile }
    var upload: (UploadImage) async throws -> String = { _ in "https://cdn.example.com/p.png" }
    var update: (String, String, String?) async throws -> MyProfile = { nickname, introduction, _ in
        MyProfile(id: 1, nickname: nickname, email: "moa@example.com", profileImageURL: nil, introduction: introduction)
    }
    private(set) var uploads: [UploadImage] = []
    private(set) var updates: [(nickname: String, introduction: String, imageURL: String?)] = []

    func fetchMyProfile() async throws -> MyProfile { try await fetch() }

    func uploadProfileImage(_ image: UploadImage) async throws -> String {
        uploads.append(image)
        return try await upload(image)
    }

    func updateMyProfile(nickname: String, introduction: String, profileImageURL: String?) async throws -> MyProfile {
        updates.append((nickname, introduction, profileImageURL))
        return try await update(nickname, introduction, profileImageURL)
    }
}
