@MainActor
protocol UserRepository {
    func fetchMyProfile() async throws -> MyProfile
    /// 사진을 올리고 수정 요청에 담을 주소를 돌려준다. 올리기만 해서는 프로필이 바뀌지 않는다.
    /// 형식이나 크기가 허용 범위를 벗어나면 `ImageUploadError` 를 던진다.
    func uploadProfileImage(_ image: UploadImage) async throws -> String
    /// `profileImageURL` 이 nil 이면 사진은 건드리지 않는다.
    func updateMyProfile(nickname: String, introduction: String, profileImageURL: String?) async throws -> MyProfile
}
