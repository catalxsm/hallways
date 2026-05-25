import Foundation
import UIKit
import ImageIO

enum ImageStorage {
    enum StorageError: Error {
        case encodingFailed
        case writeFailed(Error)
    }

    /// Longest-edge cap (in pixels) applied when saving. A 12MP phone photo
    /// (~4032px) decodes to ~48MB in memory; capping at 1600px brings that
    /// down to well under 10MB while staying sharp at on-screen sizes.
    static let maxSaveDimension: CGFloat = 1600

    /// Default longest-edge cap applied when loading user photos from disk.
    static let defaultLoadMaxPixel: CGFloat = 1200

    static func saveJPEG(_ image: UIImage, quality: CGFloat = 0.85) throws -> String {
        let downsized = downsample(image, maxDimension: maxSaveDimension)
        guard let data = downsized.jpegData(compressionQuality: quality) else {
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

    /// Loads an image. Asset-catalog images are returned as-is (already small).
    /// User photos in Documents are decoded *downsampled* via ImageIO so we
    /// never hold a full-resolution bitmap in memory.
    static func loadImage(named filename: String, maxPixel: CGFloat = defaultLoadMaxPixel) -> UIImage? {
        if let asset = UIImage(named: filename) {
            return asset
        }
        let url = documentsURL().appendingPathComponent(filename)
        return downsampledImage(at: url, maxPixel: maxPixel)
    }

    static func deleteImage(named filename: String) {
        let url = documentsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Downsampling helpers

    /// Decodes an image from disk at a reduced size using ImageIO. The full
    /// resolution is never loaded into memory — ImageIO produces the thumbnail
    /// directly, which is the key to avoiding the large CMPhoto IOSurfaces.
    private static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        let scale = UIScreen.main.scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel * scale
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    /// Redraws a UIImage so its longest edge is at most `maxDimension` points.
    /// Returns the original untouched if it's already small enough.
    private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let ratio = maxDimension / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // we're working in pixel-equivalent points already
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
