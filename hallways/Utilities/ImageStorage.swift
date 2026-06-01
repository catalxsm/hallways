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

    /// Memory cache of decoded UIImages keyed by filename. SwiftUI re-evaluates
    /// view bodies frequently; without this, each render re-decodes the JPEG
    /// from disk via ImageIO on the main thread.
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    /// Memory cache of image pixel dimensions, read from JPEG headers without
    /// decoding the bitmap. Used by callers that only need width/height.
    private static let sizeCache: NSCache<NSString, NSValue> = {
        let cache = NSCache<NSString, NSValue>()
        cache.countLimit = 500
        return cache
    }()

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
    /// never hold a full-resolution bitmap in memory. Both paths are cached.
    static func loadImage(named filename: String, maxPixel: CGFloat = defaultLoadMaxPixel) -> UIImage? {
        let key = filename as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        if let asset = UIImage(named: filename) {
            imageCache.setObject(asset, forKey: key, cost: estimatedBytes(asset))
            return asset
        }
        let url = documentsURL().appendingPathComponent(filename)
        guard let image = downsampledImage(at: url, maxPixel: maxPixel) else {
            return nil
        }
        imageCache.setObject(image, forKey: key, cost: estimatedBytes(image))
        return image
    }

    /// Returns the image's displayed pixel dimensions without decoding the
    /// bitmap. Reads the JPEG header for user photos; falls back to UIImage
    /// for asset-catalog images.
    static func imageSize(named filename: String) -> CGSize? {
        let key = filename as NSString
        if let cached = sizeCache.object(forKey: key) {
            return cached.cgSizeValue
        }
        if let cached = imageCache.object(forKey: key) {
            let size = cached.size
            sizeCache.setObject(NSValue(cgSize: size), forKey: key)
            return size
        }
        if let asset = UIImage(named: filename) {
            let size = asset.size
            sizeCache.setObject(NSValue(cgSize: size), forKey: key)
            return size
        }
        let url = documentsURL().appendingPathComponent(filename)
        guard let size = pixelSize(at: url) else { return nil }
        sizeCache.setObject(NSValue(cgSize: size), forKey: key)
        return size
    }

    static func deleteImage(named filename: String) {
        let url = documentsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        let key = filename as NSString
        imageCache.removeObject(forKey: key)
        sizeCache.removeObject(forKey: key)
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

    /// Reads pixel width/height from an image's metadata without decoding the
    /// bitmap. Honors EXIF orientation so the returned size matches what the
    /// image will look like on screen.
    private static func pixelSize(at url: URL) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let widthNum = props[kCGImagePropertyPixelWidth] as? NSNumber,
              let heightNum = props[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        let width = CGFloat(widthNum.doubleValue)
        let height = CGFloat(heightNum.doubleValue)
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        // EXIF orientations 5-8 swap the displayed axes.
        return orientation >= 5
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    private static func estimatedBytes(_ image: UIImage) -> Int {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        return Int(w * h * 4)
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
