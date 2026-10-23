import Foundation

nonisolated protocol ImageUploader: Sendable {
    /// 올릴 모양으로 바꾼다. 발급 요청에 이 결과의 형식·크기를 보내야 업로드 서명과 맞는다.
    func prepare(_ image: UploadImage, maxFileSize: Int) async throws -> UploadImage
    func upload(_ image: UploadImage, to uploadURL: URL) async throws
}

/// presigned URL 로 사진을 올린다.
///
/// 인증 헤더를 붙이지 않는다. 주소에 서명이 들어 있어 `Authorization` 이 함께 가면 스토리지가 거절한다.
nonisolated struct PresignedImageUploader: ImageUploader {
    private let transport: APIClient.Transport

    init(transport: @escaping APIClient.Transport) {
        self.transport = transport
    }

    func prepare(_ image: UploadImage, maxFileSize: Int) async throws -> UploadImage {
        try await ImageCompressor.compress(image, maxFileSize: maxFileSize)
    }

    func upload(_ image: UploadImage, to uploadURL: URL) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        // 발급 요청 때 보낸 값과 같아야 한다. 서명에 포함된다.
        request.setValue(image.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = image.data

        let response: URLResponse
        do {
            (_, response) = try await transport(request)
        } catch let error as URLError {
            if error.code == .cancelled || Task.isCancelled { throw CancellationError() }
            throw NetworkError.connection(error.code)
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw NetworkError.http(statusCode: http.statusCode) }
    }
}
