import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 올리기 전에 사진을 줄인다. 결과는 늘 JPEG 이고 EXIF 는 남기지 않는다.
nonisolated enum ImageCompressor {
    struct Step: Equatable, Sendable {
        let maxPixelSize: Int
        let quality: Double
    }

    /// 앞에서부터 해 보고 한도 안에 드는 첫 결과를 쓴다.
    static let steps = [
        Step(maxPixelSize: 2048, quality: 0.8),
        Step(maxPixelSize: 2048, quality: 0.7),
        Step(maxPixelSize: 2048, quality: 0.6),
        Step(maxPixelSize: 2048, quality: 0.5),
        Step(maxPixelSize: 1600, quality: 0.5),
        Step(maxPixelSize: 1280, quality: 0.5)
    ]

    static func firstFitting(
        maxFileSize: Int, encode: (Step) throws(ImageUploadError) -> Data
    ) throws(ImageUploadError) -> Data {
        for step in steps {
            let data = try encode(step)
            if data.count <= maxFileSize { return data }
        }
        throw .tooLarge(maxFileSize: maxFileSize)
    }

    /// 원본 전체를 풀지 않고 줄여 읽는다. 메인 스레드 밖에서 돈다.
    @concurrent
    static func compress(_ image: UploadImage, maxFileSize: Int) async throws(ImageUploadError) -> UploadImage {
        UploadImage(data: try jpeg(from: image.data, maxFileSize: maxFileSize), contentType: "image/jpeg")
    }

    static func jpeg(from data: Data, maxFileSize: Int) throws(ImageUploadError) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw .unreadable }
        // 같은 크기 단계는 줄인 이미지를 다시 쓰고 화질만 바꾼다.
        var resized: (maxPixelSize: Int, image: CGImage)?
        return try firstFitting(maxFileSize: maxFileSize) { step throws(ImageUploadError) -> Data in
            if resized?.maxPixelSize != step.maxPixelSize {
                guard let image = thumbnail(source, maxPixelSize: step.maxPixelSize) else { throw .unreadable }
                resized = (step.maxPixelSize, image)
            }
            guard let image = resized?.image, let jpeg = encode(image, quality: step.quality) else { throw .unreadable }
            return jpeg
        }
    }

    /// 회전 정보는 픽셀에 반영한다. 원본보다 크게 키우지 않는다.
    private static func thumbnail(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let longSide = max(
            properties?[kCGImagePropertyPixelWidth] as? Int ?? 0,
            properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        )
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: longSide > 0 ? min(longSide, maxPixelSize) : maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encode(_ image: CGImage, quality: Double) -> Data? {
        guard let opaque = flattened(image) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, opaque, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// 투명한 곳은 흰색으로 채운다. JPEG 는 투명도를 담지 못한다.
    private static func flattened(_ image: CGImage) -> CGImage? {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let spaces = [image.colorSpace, CGColorSpace(name: CGColorSpace.sRGB)].compactMap { $0 }.filter { $0.model == .rgb }
        for space in spaces {
            guard let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(rect)
            context.draw(image, in: rect)
            return context.makeImage()
        }
        return nil
    }
}
