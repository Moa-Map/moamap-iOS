import Foundation

/// 서버가 이미지 업로드 주소를 발급해 주는 범위. 형식은 어느 용도든 같지만 크기 한도는 용도마다 다르다.
nonisolated enum ImageUploadRules {
    static let allowedContentTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]

    private static let megabyte = 1024 * 1024

    /// 지도 커버와 프로필 이미지.
    static let maxImageFileSize = 10 * megabyte
    static let maxPlacePhotoFileSize = 5 * megabyte
    static let maxPostPhotoFileSize = 5 * megabyte
    static let maxReviewPhotoFileSize = 5 * megabyte

    /// 발급을 요청하기 전에 거른다. 서버 400 을 받고 나면 무엇이 문제인지 알려줄 수 없다.
    static func validate(contentType: String, fileSize: Int, maxFileSize: Int = maxImageFileSize) throws(ImageUploadError) {
        guard allowedContentTypes.contains(contentType.lowercased()) else { throw .unsupportedType }
        guard fileSize <= maxFileSize else { throw .tooLarge(maxFileSize: maxFileSize) }
    }

    static func megabytes(_ bytes: Int) -> Int { bytes / megabyte }
}

nonisolated enum ImageUploadError: Error, Equatable, Sendable {
    case unsupportedType
    /// 한도가 용도마다 달라 문구에 실제 한도를 넣는다.
    case tooLarge(maxFileSize: Int)
    /// 고른 사진을 읽거나 변환하지 못했다.
    case unreadable

    var userMessage: String {
        switch self {
        case .unsupportedType: "JPG, PNG, WEBP 형식만 올릴 수 있어요"
        case .tooLarge(let maxFileSize): "사진 크기는 \(ImageUploadRules.megabytes(maxFileSize))MB 이하여야 해요"
        case .unreadable: "사진을 불러오지 못했어요"
        }
    }
}
