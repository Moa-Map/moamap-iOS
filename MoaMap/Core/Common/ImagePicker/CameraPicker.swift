import AVFoundation
import SwiftUI
import UIKit

/// 시스템 카메라로 한 장 찍는다. 촬영본은 JPEG 로 넘긴다.
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    /// 아직 묻지 않았으면 묻는다. 거부했으면 false.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// 카메라를 열 수 없을 때의 안내.
enum CameraAlert {
    case unavailable
    case denied

    var title: String {
        switch self {
        case .unavailable: "카메라를 사용할 수 없어요"
        case .denied: "카메라 권한이 필요해요"
        }
    }

    var message: String {
        switch self {
        case .unavailable: "이 기기에서는 카메라를 쓸 수 없어요. 갤러리에서 사진을 골라주세요."
        case .denied: "설정에서 카메라 접근을 허용하면 사진을 찍을 수 있어요."
        }
    }
}

extension View {
    /// `isRequested` 가 켜지면 카메라를 연다. 기기에 없거나 권한이 없으면 안내를 띄운다.
    /// 찍은 사진은 카메라가 다 닫힌 뒤에 넘긴다. 닫히는 중에 다른 화면을 닫으면 UIKit 이 무시한다.
    func cameraCapture(isRequested: Binding<Bool>, onCaptured: @escaping (Data) -> Void) -> some View {
        modifier(CameraCaptureModifier(isRequested: isRequested, onCaptured: onCaptured))
    }
}

private struct CameraCaptureModifier: ViewModifier {
    @Environment(\.openURL) private var openURL

    @Binding var isRequested: Bool
    let onCaptured: (Data) -> Void

    @State private var showsCamera = false
    @State private var captured: Data?
    @State private var alert: CameraAlert?

    func body(content: Content) -> some View {
        content
            .onChange(of: isRequested) { _, requested in
                guard requested else { return }
                isRequested = false
                open()
            }
            .fullScreenCover(isPresented: $showsCamera, onDismiss: {
                guard let data = captured else { return }
                captured = nil
                onCaptured(data)
            }) {
                CameraPicker { captured = $0 }
                    .ignoresSafeArea()
            }
            .alert(alert?.title ?? "", isPresented: showsAlert, presenting: alert) { alert in
                if alert == .denied {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    Button("취소", role: .cancel) {}
                } else {
                    Button("확인", role: .cancel) {}
                }
            } message: { alert in
                Text(alert.message)
            }
    }

    private func open() {
        guard CameraPicker.isAvailable else {
            alert = .unavailable
            return
        }
        Task {
            if await CameraPicker.requestAccess() { showsCamera = true } else { alert = .denied }
        }
    }

    private var showsAlert: Binding<Bool> {
        Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })
    }
}
