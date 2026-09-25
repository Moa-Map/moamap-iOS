import SwiftUI

/// 브랜드 스타일은 로그인 화면에 한정한다.
struct SocialLoginButton: View {
    enum Provider {
        case google, kakao, apple

        var title: String {
            switch self {
            case .google: "Google로 로그인"
            case .kakao: "카카오 로그인"
            case .apple: "APPLE로 로그인"
            }
        }

        var assetName: String {
            switch self {
            case .google: "Icons/google"
            case .kakao: "Icons/kakao"
            case .apple: "Icons/apple"
            }
        }

        var background: Color {
            switch self {
            case .google: .white
            case .kakao: Color(argb: 0xFFFE_E500)
            case .apple: Color(argb: 0xFF15_1617)
            }
        }

        var foreground: Color {
            switch self {
            case .google: Color(argb: 0xFF1F_1F1F).opacity(0.85)
            case .kakao: .black.opacity(0.85)
            case .apple: .white
            }
        }
    }

    let provider: Provider
    var isLoading = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(provider.foreground)
                        .frame(width: 24, height: 24)
                } else {
                    Image(provider.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }

                Text(provider.title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(provider.foreground)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 53)
            .background(provider.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if provider == .google {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(argb: 0xFF74_7775), lineWidth: 1)
                }
            }
            .shadow(
                color: .black.opacity(provider == .apple ? 0.17 : 0),
                radius: 1.5, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil || isLoading)
        .accessibilityLabel(provider.title)
        .accessibilityValue(isLoading ? "로그인 중" : "")
    }
}
