import Foundation
import UIKit

enum ImageStorage {
    enum StorageError: Error {
        case encodingFailed
        case writeFailed(Error)
    }

    static func saveJPEG(_ image: UIImage, quality: CGFloat = 0.85) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StorageError.encodingFailed
        }
        let filename = "\(UUID().uuidString).jpg"
        let url = documentsURL().appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw StorageError.writeFailed(error)
        }
        return filename
    }

    static func loadImage(named filename: String) -> UIImage? {
        if let asset = UIImage(named: filename) {
            return asset
        }
        let url = documentsURL().appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    static func deleteImage(named filename: String) {
        let url = documentsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    private static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
