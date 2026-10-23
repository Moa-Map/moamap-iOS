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
    @State private var bottom: CGFloat = 0

    private var overlap: CGFloat {
        guard let keyboardTop else { return 0 }
        return max(0, bottom - keyboardTop)
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottom = $0 }
            .safeAreaPadding(.bottom, overlap)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                withAnimation(.easeOut(duration: 0.25)) { keyboardTop = frame.minY }
            }
    }
}
