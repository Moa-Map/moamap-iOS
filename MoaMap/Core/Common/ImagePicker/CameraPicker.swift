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
