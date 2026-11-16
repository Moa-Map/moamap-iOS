import SwiftUI
import UIKit

extension View {
    /// 키보드를 피하지 않는 화면에서, 스크롤 영역이 키보드에 가리는 만큼만 아래를 줄인다.
    /// 아래 버튼이 키보드를 따라 올라오지 않게 화면에 `.ignoresSafeArea(.keyboard, edges: .bottom)` 를 함께 건다.
    func keyboardOverlapPadding() -> some View {
        modifier(KeyboardOverlapPadding())
    }
}

private struct KeyboardOverlapPadding: ViewModifier {
    @State private var keyboardTop: CGFloat?
    @State private var frame: CGRect = .zero

    /// 여백이 영역 높이를 넘으면 바깥 배치가 흔들려 다시 잰 값이 바뀐다. 영역 높이까지만 준다.
    private var overlap: CGFloat {
        guard let keyboardTop else { return 0 }
        return min(max(0, frame.maxY - keyboardTop), frame.height)
    }

    func body(content: Content) -> some View {
        // 여백 바깥에서 잰다. 안쪽에서 재면 넣은 여백만큼 값이 바뀌어 여백을 넣고 빼기를 되풀이한다.
        content
            .safeAreaPadding(.bottom, overlap)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                // 화면 아래에 붙지 않은 키보드(떠 있는 키보드, 회전 중 잠깐 오는 값)는 가리지 않는 것으로 본다.
                let screenBottom = (note.object as? UIScreen)?.bounds.maxY ?? end.maxY
                let top = end.maxY < screenBottom - 1 ? screenBottom : end.minY
                // 키보드와 같은 시간에 맞춘다. 키보드를 바꿀 때처럼 바로 바뀌면 여백도 바로 넣어야 입력칸을 맞출 때 어긋나지 않는다.
                let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
                withAnimation(duration > 0 ? .easeOut(duration: duration) : nil) { keyboardTop = top }
            }
    }
}
