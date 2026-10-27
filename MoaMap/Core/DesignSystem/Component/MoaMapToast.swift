import SwiftUI

/// 토스트에 띄울 안내. 해낸 일에만 체크를 붙인다.
struct ToastMessage: Equatable {
    let text: String
    var showsCheck = true

    /// 실패 안내. 체크를 붙이면 된 것처럼 읽힌다.
    static func failure(_ text: String) -> ToastMessage {
        ToastMessage(text: text, showsCheck: false)
    }
}

/// 가운데 아래에 잠깐 떴다 사라지는 알약 모양 안내.
struct MoaMapToast: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let message: ToastMessage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32)

        HStack(spacing: 8) {
            if message.showsCheck {
                Image("Icons/check-small").renderingMode(.template).resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(colors.textWhite)
                    .padding(3)
                    .background(MoaMapPrimitiveColors.blue500, in: Circle())
                    .accessibilityHidden(true)
            }
            Text(message.text)
                .moaTextStyle(typography.caption0)
                .foregroundStyle(colors.textWhite)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            shape.fill(.ultraThinMaterial)
            shape.fill(MoaMapPrimitiveColors.gray500.opacity(0.7))
        }
        .padding(.horizontal, 20)
    }
}

extension View {
    /// 값이 들어오면 바로 비우고 잠깐 띄운다. 띄우는 동안 다시 들어오면 새 안내로 바꾼다.
    /// `bottomInset` 은 아래에 떠 있는 입력창 등을 피해 올리는 높이다.
    func moaToast(_ message: Binding<ToastMessage?>, duration: Duration = .seconds(2), bottomInset: CGFloat = 0) -> some View {
        modifier(ToastModifier(message: message, duration: duration, bottomInset: bottomInset))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?
    let duration: Duration
    let bottomInset: CGFloat
    /// 같은 문구가 연달아 와도 다시 띄우도록 순번을 붙인다.
    @State private var shown: (message: ToastMessage, serial: Int)?
    @State private var serial = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let shown {
                    MoaMapToast(message: shown.message)
                        .padding(.bottom, bottomInset)
                        .transition(.opacity)
                        .onTapGesture { self.shown = nil }
                        .id(shown.serial)
                }
            }
            .animation(.easeOut(duration: 0.2), value: shown?.serial)
            .onChange(of: message, initial: true) { _, arrived in
                guard let arrived else { return }
                serial += 1
                shown = (arrived, serial)
                message = nil
                UIAccessibility.post(notification: .announcement, argument: arrived.text)
            }
            .task(id: shown?.serial) {
                guard shown != nil else { return }
                try? await Task.sleep(for: duration)
                if !Task.isCancelled { shown = nil }
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        MoaMapToast(message: ToastMessage(text: "신고가 접수됐어요"))
        MoaMapToast(message: .failure("이미 신고했어요"))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.8))
}
