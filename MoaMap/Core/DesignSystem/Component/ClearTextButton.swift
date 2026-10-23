import SwiftUI

/// 입력한 글자가 있을 때 입력창 오른쪽에 두는 지우기 버튼.
struct ClearTextButton: View {
    @Environment(\.moaColors) private var colors

    @Binding var text: String

    var body: some View {
        if !text.isEmpty {
            Button { text = "" } label: {
                Image("Icons/cancel")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(colors.textAlternative)
                    // 그림은 20 이지만 누르는 칸은 넓힌다. 칸 높이는 그대로 둔다.
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .padding(-6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("입력 지우기")
        }
    }
}
