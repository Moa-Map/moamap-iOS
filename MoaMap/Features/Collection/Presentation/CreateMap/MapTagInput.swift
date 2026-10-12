import Foundation

/// 지도 만들기와 지도 정보 수정이 함께 쓰는 태그 입력 규칙.
nonisolated enum MapTagInput {
    /// 서버 `@Size(max = 30)` 제약.
    static let maxLength = 30

    /// 공백이나 줄바꿈이 들어오면 그 앞까지 태그로 확정한다. 붙여넣기로 여러 개가 들어와도 같다.
    static func apply(_ input: String, to tags: [String]) -> (tags: [String], pending: String) {
        let tokens = input.split(omittingEmptySubsequences: false, whereSeparator: isSeparator).map(String.init)
        guard tokens.count > 1, let pending = tokens.last else {
            return (tags, String(input.prefix(maxLength)))
        }
        return (adding(tokens.dropLast(), to: tags), String(pending.prefix(maxLength)))
    }

    /// 빈 값과 이미 담긴 태그는 거른다.
    static func adding(_ candidates: some Sequence<String>, to tags: [String]) -> [String] {
        var result = tags
        for candidate in candidates {
            let tag = String(candidate.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
            if !tag.isEmpty, !result.contains(tag) { result.append(tag) }
        }
        return result
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character == " " || character.isNewline
    }
}
