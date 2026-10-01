import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 올릴 사진 한 장. `contentType` 은 업로드 주소 서명에 들어가 발급 요청과 업로드에 같은 값을 쓴다.
nonisolated struct UploadImage: Equatable, Sendable {
    let data: Data
    let contentType: String

    var fileSize: Int { data.count }

    /// 고른 사진을 서버가 받는 형식으로 맞춘다. HEIC 처럼 허용되지 않는 형식은 JPEG 로 바꾼다.
    init(pickedData data: Data, type: UTType?) throws(ImageUploadError) {
        if let type, let mimeType = type.preferredMIMEType, ImageUploadRules.allowedContentTypes.contains(mimeType) {
            self.init(data: data, contentType: mimeType)
            return
        }
        guard let jpeg = Self.jpegData(from: data) else { throw .unreadable }
        self.init(data: jpeg, contentType: "image/jpeg")
    }

    init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }

    private static let jpegQuality = 0.9

    private static func jpegData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        // 방향 정보는 그대로 옮겨 사진이 돌아가 보이지 않게 한다.
        let options = [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        CGImageDestinationAddImageFromSource(destination, source, 0, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
