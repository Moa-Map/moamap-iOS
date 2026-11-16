import SwiftUI

/// 받은 값을 고쳐 넣는 입력칸에 쓴다. 고친 값이 이전과 같으면 TextField 가 다시 그려지지 않아
/// 넘친 글자가 화면에 남는다. 화면 값을 따로 들고 있다가 고친 값으로 되돌린다.
struct DraftTextInput<Content: View>: View {
    private let get: () -> String
    private let set: (String) -> Void
    private let content: (Binding<String>) -> Content
    @State private var draft: String

    init(get: @escaping () -> String, set: @escaping (String) -> Void, @ViewBuilder content: @escaping (Binding<String>) -> Content) {
        self.get = get
        self.set = set
        self.content = content
        _draft = State(initialValue: get())
    }

    var body: some View {
        content($draft)
            .onChange(of: draft) { _, new in
                set(new)
                let applied = get()
                if applied != new { draft = applied }
            }
            .onChange(of: get()) { _, new in
                if new != draft { draft = new }
            }
    }
}
