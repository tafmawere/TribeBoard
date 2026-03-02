import SwiftUI
import UIKit
import Foundation

struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

func prepareAvatarJPEGData(from image: UIImage, quality: CGFloat = 0.7) -> Data? {
    let squareImage = centerCroppedSquareImage(from: image)
    return squareImage.jpegData(compressionQuality: quality)
}

func centerCroppedSquareImage(from image: UIImage) -> UIImage {
    let originalSize = image.size
    let side = min(originalSize.width, originalSize.height)
    let originX = (originalSize.width - side) / 2.0
    let originY = (originalSize.height - side) / 2.0
    let cropRect = CGRect(x: originX, y: originY, width: side, height: side)

    if let cgImage = image.cgImage?.cropping(to: cropRect) {
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    return image
}

enum AvatarPhotoStore {
    private static let directoryName = "Avatars"

    static func saveAvatarPhoto(from image: UIImage, memberId: UUID) -> String? {
        let squareImage = centerCroppedSquareImage(from: image)
        guard let data = squareImage.jpegData(compressionQuality: 0.78) else { return nil }
        guard let avatarsDirectory = avatarsDirectoryURL() else { return nil }

        let fileName = "\(memberId.uuidString).jpg"
        let fileURL = avatarsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: [.atomic])
            return fileName
        } catch {
            return nil
        }
    }

    static func resolvePhotoURL(from reference: String?) -> URL? {
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines), !reference.isEmpty else {
            return nil
        }
        if reference.hasPrefix("http://") || reference.hasPrefix("https://") || reference.hasPrefix("file://") {
            return URL(string: reference)
        }
        guard let avatarsDirectory = avatarsDirectoryURL() else { return nil }
        return avatarsDirectory.appendingPathComponent(reference)
    }

    static func deletePhoto(reference: String?) {
        guard let fileURL = resolvePhotoURL(from: reference), fileURL.isFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func avatarsDirectoryURL() -> URL? {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appendingPathComponent(directoryName, isDirectory: true)
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            return directory
        } catch {
            return nil
        }
    }
}
