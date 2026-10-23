import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 올릴 사진 한 장. `contentType` 은 업로드 주소 서명에 들어가 발급 요청과 업로드에 같은 값을 쓴다.
nonisolated struct UploadImage: Equatable, Sendable {
    let data: Data
    let contentType: String

    var fileSize: Int { data.count }

    /// 고른 원본을 그대로 담는다. 줄이고 JPEG 로 바꾸는 것은 올릴 때 `ImageUploader.prepare` 가 한다.
    /// 허용되지 않는 형식은 읽을 수 있는 사진인지만 미리 본다.
    init(pickedData data: Data, type: UTType?) throws(ImageUploadError) {
        if let type, let mimeType = type.preferredMIMEType, ImageUploadRules.allowedContentTypes.contains(mimeType) {
            self.init(data: data, contentType: mimeType)
            return
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let mimeType = CGImageSourceGetType(source).flatMap({ UTType($0 as String) })?.preferredMIMEType else {
            throw .unreadable
        }
        self.init(data: data, contentType: mimeType)
    }

    init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}
