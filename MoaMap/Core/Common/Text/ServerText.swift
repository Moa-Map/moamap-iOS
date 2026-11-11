/// 서버 `@Size` 는 UTF-16 단위로 센다. 입력 길이는 이 기준으로 세고 자른다.
nonisolated extension String {
    var serverLength: Int { utf16.count }

    /// UTF-16 길이가 `maxLength` 를 넘지 않는 데까지 남긴다. 글자 중간에서는 자르지 않는다.
    func limitedToServerLength(_ maxLength: Int) -> String {
        guard serverLength > maxLength else { return self }
        var length = 0
        var end = startIndex
        for index in indices {
            length += self[index].utf16.count
            if length > maxLength { break }
            end = self.index(after: index)
        }
        return String(self[..<end])
    }
}
