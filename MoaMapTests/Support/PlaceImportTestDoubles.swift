import Foundation
@testable import MoaMap

nonisolated struct CaptionExtractorStub: CaptionExtractor {
    var result: CaptionResult = .success("캡션")

    func extract(_ url: String) async throws -> CaptionResult { result }
}

extension ImportedPlace {
    static func fixture(id: String, savable: Bool = true, description: String? = nil) -> ImportedPlace {
        ImportedPlace(
            id: id, name: "장소 \(id)", address: "성수동", latitude: 37.5, longitude: 127.0,
            category: "카페", description: description, kakaoPlaceID: savable ? id : nil,
            sourceType: "INSTAGRAM", sourceURL: "https://www.instagram.com/p/A1/"
        )
    }
}
