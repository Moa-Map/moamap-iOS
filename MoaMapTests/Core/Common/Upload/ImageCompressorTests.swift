import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

struct ImageCompressorStepTests {
    private typealias Step = ImageCompressor.Step

    @Test func 단계는_2048에서_화질을_낮추고_그다음_크기를_줄인다() {
        #expect(ImageCompressor.steps == [
            Step(maxPixelSize: 2048, quality: 0.8),
            Step(maxPixelSize: 2048, quality: 0.7),
            Step(maxPixelSize: 2048, quality: 0.6),
            Step(maxPixelSize: 2048, quality: 0.5),
            Step(maxPixelSize: 1600, quality: 0.5),
            Step(maxPixelSize: 1280, quality: 0.5)
        ])
    }

    @Test func 첫_결과가_한도_안이면_더_줄이지_않는다() throws {
        var tried: [Step] = []
        let data = try ImageCompressor.firstFitting(maxFileSize: 10) { step in
            tried.append(step)
            return Data(count: 10)
        }
        #expect(data.count == 10)
        #expect(tried == [ImageCompressor.steps[0]])
    }

    @Test func 한도를_넘으면_한도_안에_드는_첫_단계에서_멈춘다() throws {
        var tried: [Step] = []
        let data = try ImageCompressor.firstFitting(maxFileSize: 5) { step in
            tried.append(step)
            return Data(count: step.maxPixelSize == 1600 ? 5 : 6)
        }
        #expect(data.count == 5)
        #expect(tried == Array(ImageCompressor.steps.prefix(5)))
    }

    @Test func 끝까지_넘으면_한도를_담아_막는다() {
        var tried: [Step] = []
        #expect(throws: ImageUploadError.tooLarge(maxFileSize: 5)) {
            try ImageCompressor.firstFitting(maxFileSize: 5) { step in
                tried.append(step)
                return Data(count: 6)
            }
        }
        #expect(tried == ImageCompressor.steps)
    }

    @Test func 만들지_못하면_그_자리에서_멈춘다() {
        var count = 0
        #expect(throws: ImageUploadError.unreadable) {
            try ImageCompressor.firstFitting(maxFileSize: 5) { _ throws(ImageUploadError) -> Data in
                count += 1
                throw .unreadable
            }
        }
        #expect(count == 1)
    }
}

struct ImageCompressorTests {
    private static let limit = ImageUploadRules.maxPlacePhotoFileSize

    private func image(
        width: Int, height: Int, type: UTType, alpha: CGFloat = 1, properties: [CFString: Any] = [:]
    ) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: alpha)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func properties(_ data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func size(_ properties: [CFString: Any]) -> (Int, Int) {
        (properties[kCGImagePropertyPixelWidth] as? Int ?? 0, properties[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    @Test func 긴_변을_2048로_줄이고_비율은_지킨다() throws {
        let jpeg = try ImageCompressor.jpeg(from: try image(width: 3000, height: 1500, type: .png), maxFileSize: Self.limit)
        #expect(size(try properties(jpeg)) == (2048, 1024))
    }

    @Test func 작은_사진은_키우지_않는다() throws {
        let jpeg = try ImageCompressor.jpeg(from: try image(width: 100, height: 50, type: .png), maxFileSize: Self.limit)
        #expect(size(try properties(jpeg)) == (100, 50))
    }

    @Test func 투명한_곳은_흰색으로_채운다() throws {
        let jpeg = try ImageCompressor.jpeg(from: try image(width: 8, height: 8, type: .png, alpha: 0), maxFileSize: Self.limit)
        let source = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(decoded, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(pixel.prefix(3).allSatisfy { $0 > 245 })
    }

    @Test func 회전_정보는_픽셀에_반영하고_위치_정보는_남기지_않는다() throws {
        let original = try image(width: 40, height: 20, type: .jpeg, properties: [
            kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 37.5, kCGImagePropertyGPSLatitudeRef: "N"]
        ])
        let jpeg = try ImageCompressor.jpeg(from: original, maxFileSize: Self.limit)
        let result = try properties(jpeg)
        #expect(size(result) == (20, 40))
        #expect((result[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(result[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func 끝까지_한도를_넘으면_막는다() throws {
        let original = try image(width: 100, height: 100, type: .png)
        #expect(throws: ImageUploadError.tooLarge(maxFileSize: 1)) {
            try ImageCompressor.jpeg(from: original, maxFileSize: 1)
        }
    }

    @Test func 사진이_아니면_읽지_못했다고_알린다() {
        #expect(throws: ImageUploadError.unreadable) {
            try ImageCompressor.jpeg(from: Data("not image".utf8), maxFileSize: Self.limit)
        }
    }

    @Test func 줄인_결과는_JPEG_로_올린다() async throws {
        let picked = UploadImage(data: try image(width: 10, height: 10, type: .png), contentType: "image/png")
        let result = try await ImageCompressor.compress(picked, maxFileSize: Self.limit)
        #expect(result.contentType == "image/jpeg")
        _ = try properties(result.data)
    }
}
