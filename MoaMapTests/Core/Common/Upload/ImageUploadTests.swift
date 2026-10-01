import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

struct ImageUploadRulesTests {
    @Test(arguments: ["image/jpeg", "image/png", "image/webp", "IMAGE/JPEG"])
    func 허용된_형식은_통과한다(contentType: String) throws {
        try ImageUploadRules.validate(contentType: contentType, fileSize: 1)
    }

    @Test(arguments: ["image/heic", "image/gif", "application/pdf"])
    func 허용되지_않은_형식은_막는다(contentType: String) {
        #expect(throws: ImageUploadError.unsupportedType) {
            try ImageUploadRules.validate(contentType: contentType, fileSize: 1)
        }
    }

    @Test func 한도를_넘으면_실제_한도를_담아_막는다() {
        let limit = ImageUploadRules.maxPlacePhotoFileSize
        #expect(throws: ImageUploadError.tooLarge(maxFileSize: limit)) {
            try ImageUploadRules.validate(contentType: "image/png", fileSize: limit + 1, maxFileSize: limit)
        }
        #expect(ImageUploadError.tooLarge(maxFileSize: limit).userMessage == "사진 크기는 5MB 이하여야 해요")
    }

    @Test func 한도와_같으면_통과한다() throws {
        try ImageUploadRules.validate(contentType: "image/jpeg", fileSize: ImageUploadRules.maxImageFileSize)
    }
}

struct UploadImageTests {
    private func pngData() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func 허용된_형식은_그대로_올린다() throws {
        let data = try pngData()
        let image = try UploadImage(pickedData: data, type: .png)
        #expect(image == UploadImage(data: data, contentType: "image/png"))
    }

    @Test func 허용되지_않은_형식은_JPEG_로_바꾼다() throws {
        let image = try UploadImage(pickedData: try pngData(), type: .heic)
        #expect(image.contentType == "image/jpeg")
        let source = try #require(CGImageSourceCreateWithData(image.data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
    }

    @Test func 이미지가_아니면_읽지_못했다고_알린다() {
        #expect(throws: ImageUploadError.unreadable) {
            try UploadImage(pickedData: Data("not image".utf8), type: nil)
        }
    }
}

struct PresignedImageUploaderTests {
    private let url = URL(string: "https://storage.example.com/profile/1.png?X-Amz-Signature=abc")!

    @Test func 인증_헤더_없이_발급받은_형식으로_PUT_한다() async throws {
        let sut = PresignedImageUploader { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url == url)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/png")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.httpBody == Data([1, 2, 3]))
            return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        try await sut.upload(UploadImage(data: Data([1, 2, 3]), contentType: "image/png"), to: url)
    }

    @Test func 스토리지가_거절하면_오류를_던진다() async {
        let sut = PresignedImageUploader { [url] _ in
            (Data(), HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: NetworkError.http(statusCode: 403)) {
            try await sut.upload(UploadImage(data: Data([1]), contentType: "image/png"), to: url)
        }
    }

    @Test func 연결_실패는_연결_오류로_바꾼다() async {
        let sut = PresignedImageUploader { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: NetworkError.connection(.notConnectedToInternet)) {
            try await sut.upload(UploadImage(data: Data([1]), contentType: "image/png"), to: url)
        }
    }
}
