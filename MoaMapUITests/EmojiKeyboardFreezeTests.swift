import XCTest

/// 이모지 키보드로 바꿔도 화면이 멈추지 않는지 본다.
/// 앱은 `-UITestScreen` 실행 인자로 로그인 없이 화면 하나만 띄운다.
final class EmojiKeyboardFreezeTests: XCTestCase {
    /// 키 하나 누르는 데 이보다 오래 걸리면 멈춘 것으로 본다.
    private static let responseLimit: TimeInterval = 5

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testCreateMap() throws { try checkEmojiKeyboard(screen: "createMap", field: .textField) }
    @MainActor func testEditMap() throws { try checkEmojiKeyboard(screen: "editMap", field: .textField) }
    /// 이메일 칸은 이모지를 거르므로 내용 칸에서 본다.
    @MainActor func testInquiry() throws { try checkEmojiKeyboard(screen: "inquiry", field: .textView) }
    @MainActor func testProfileEdit() throws { try checkEmojiKeyboard(screen: "profileEdit", field: .textField) }

    @MainActor
    private func checkEmojiKeyboard(screen: String, field type: XCUIElement.ElementType) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScreen", screen]
        app.launch()

        // 이모지 키보드의 검색칸도 textField 라, 화면 창 안에서만 찾는다.
        let field = app.windows.firstMatch.descendants(matching: type).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        // 하드웨어 키보드가 연결된 시뮬레이터는 키보드를 화면 밖에 둔다.
        if keyboard.frame.minY >= app.windows.firstMatch.frame.maxY {
            throw XCTSkip("소프트웨어 키보드가 화면 밖에 있다. 시뮬레이터의 하드웨어 키보드 연결을 끄고 다시 돌린다.")
        }

        // 일반 → 이모지 → 일반 → 이모지
        tapKey(keyboard.buttons["emoji"], name: "이모지 키")
        tapKey(keyboard.buttons["letters"], name: "글자 키")
        tapKey(keyboard.buttons["emoji"], name: "이모지 키")

        let before = field.value as? String
        let emojiKey = keyboard.keys.matching(NSPredicate(format: "identifier != 'delete'")).firstMatch
        tapKey(emojiKey, name: "이모지")
        XCTAssertNotEqual(field.value as? String, before)
    }

    /// 키보드 키는 접근성 스크롤이 안 돼 좌표로 누른다.
    @MainActor
    private func tapKey(_ key: XCUIElement, name: String) {
        XCTAssertTrue(key.waitForExistence(timeout: 3), "\(name)가 없다")
        let start = Date()
        key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, Self.responseLimit, "\(name)를 누른 뒤 \(elapsed)초 동안 응답이 없다")
    }
}
