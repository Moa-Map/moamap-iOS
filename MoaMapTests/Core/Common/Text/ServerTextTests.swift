import Testing
@testable import MoaMap

// Android 와 같은 결과여야 한다. 예시를 바꾸면 Android 테스트도 같이 바꾼다.

private func 가(_ count: Int) -> String { String(repeating: "가", count: count) }

private let limitCases: [(input: String, maxLength: Int, expected: String)] = [
    (가(99) + "😀", 100, 가(99)),
    (가(98) + "😀", 100, 가(98) + "😀"),
    (가(98) + "👨‍👩‍👧", 100, 가(98)),
    (가(96) + "🇰🇷", 100, 가(96) + "🇰🇷"),
    (가(97) + "🇰🇷", 100, 가(97)),
    (String(repeating: "😀", count: 51), 100, String(repeating: "😀", count: 50)),
    ("👍🏽", 3, ""),
    ("a👍🏽", 4, "a"),
    ("abc가나다", 100, "abc가나다"),
]

@Test(arguments: limitCases)
func 서버_길이로_자르되_글자를_쪼개지_않는다(_ example: (input: String, maxLength: Int, expected: String)) {
    #expect(example.input.limitedToServerLength(example.maxLength) == example.expected)
}

@Test
func 서버_길이는_UTF16_단위다() {
    #expect("가".serverLength == 1)
    #expect("😀".serverLength == 2)
    #expect("🇰🇷".serverLength == 4)
    #expect("👍🏽".serverLength == 4)
    #expect("👨‍👩‍👧".serverLength == 8)
}

