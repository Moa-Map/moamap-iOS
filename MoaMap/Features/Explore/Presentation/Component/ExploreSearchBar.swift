import SwiftUI

/// 지도 검색창. 서버는 지도만 찾지만 안내 문구는 시안 그대로 둔다.
struct ExploreSearchBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let query: String
    /// 화면이 빈 곳을 누를 때 키보드를 내릴 수 있게 밖에서 받는다.
    let focused: FocusState<Bool>.Binding
    let maxLength: Int
    let onQueryChange: (String) -> Void
    /// 키보드 검색 버튼.
    let onSearch: () -> Void

    /// 바깥 값이 그대로면 TextField 가 다시 그려지지 않아 넘친 글자가 남는다. 여기서 잘라 되돌린다.
    @State private var text: String

    init(
        query: String,
        focused: FocusState<Bool>.Binding,
        maxLength: Int,
        onQueryChange: @escaping (String) -> Void,
        onSearch: @escaping () -> Void
    ) {
        self.query = query
        self.focused = focused
        self.maxLength = maxLength
        self.onQueryChange = onQueryChange
        self.onSearch = onSearch
        _text = State(initialValue: query)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image("Icons/search")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(colors.textNormal)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text("장소,지도를 검색해보세요").foregroundStyle(colors.textAssistive))
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .tint(MoaMapPrimitiveColors.blue500)
                .focused(focused)
                .submitLabel(.search)
                .onSubmit(onSearch)
            ClearTextButton(text: $text)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(colors.textWhite, in: Capsule())
        .overlay { if focused.wrappedValue { Capsule().strokeBorder(colors.primary, lineWidth: 1) } }
        .shadow(color: .black.opacity(0.04), radius: 8)
        .onChange(of: text) { _, new in
            let limited = String(new.prefix(maxLength))
            if limited != new {
                text = limited
            } else if limited != query {
                onQueryChange(limited)
            }
        }
        .onChange(of: query) { _, new in
            if new != text { text = new }
        }
    }
}

#Preview {
    @Previewable @State var query = ""
    @Previewable @FocusState var focused: Bool
    ExploreSearchBar(query: query, focused: $focused, maxLength: 50, onQueryChange: { query = $0 }, onSearch: {})
        .padding()
}
