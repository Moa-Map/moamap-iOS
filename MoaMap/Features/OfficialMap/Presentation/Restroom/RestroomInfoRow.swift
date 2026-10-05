/// 카드에 쓰는 「항목 - 내용」 줄.
nonisolated struct RestroomInfoRow: Equatable, Sendable {
    let label: String
    let value: String
}

nonisolated extension RestroomDetail {
    /// 비어 있는 항목은 줄째 뺀다. 칸 수는 0인 것을 빼고 적는다. 공공데이터는 없는 시설을 0으로 채워 온다.
    var infoRows: [RestroomInfoRow] {
        let rows: [(String, String?)] = [
            ("주소", address),
            ("개방시간", Self.joined([openHours, openHoursDetail])),
            ("남자", Self.counts([("대변기", maleToilet), ("소변기", maleUrinal)])),
            ("여자", Self.counts([("대변기", femaleToilet)])),
            ("장애인용", Self.counts([("남 대변기", maleDisabledToilet), ("남 소변기", maleDisabledUrinal), ("여 대변기", femaleDisabledToilet)])),
            ("어린이용", Self.counts([("남 대변기", maleChildToilet), ("남 소변기", maleChildUrinal), ("여 대변기", femaleChildToilet)])),
            ("편의시설", Self.joined([
                diaperTable ? "기저귀 교환대" : nil,
                emergencyBell ? "비상벨" : nil,
                entranceCctv ? "입구 CCTV" : nil
            ])),
            ("관리기관", Self.joined([managerOrg, phone]))
        ]
        return rows.compactMap { label, value in value.map { RestroomInfoRow(label: label, value: $0) } }
    }

    private static func joined(_ items: [String?]) -> String? {
        let text = items.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private static func counts(_ items: [(String, Int)]) -> String? {
        joined(items.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" })
    }
}
