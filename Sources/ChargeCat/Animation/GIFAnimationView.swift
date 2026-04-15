import AppKit
import CoreGraphics
import ImageIO
import SwiftUI

struct GIFAnimationView: NSViewRepresentable {
    let asset: GIFAsset
    var frameIndex: Int?

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.canDrawSubviewsIntoLayer = true
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = false
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let frameIndex {
            nsView.image = asset.image(at: frameIndex)
            return
        }

        nsView.image = asset.animatedImage
    }
}

final class GIFAsset: @unchecked Sendable {
    static let catDoor = GIFAsset(
        resourceName: "cat-door",
        previewFrame: 75,
        onboardingFrame: 70,
        doorCreakFrame: 5,
        catChirpFrame: 40,
        sparkleFrame: 85
    )

    let previewFrame: Int
    let onboardingFrame: Int
    let doorCreakFrame: Int
    let catChirpFrame: Int
    let sparkleFrame: Int
    let frameCount: Int
    let duration: TimeInterval
    let pixelSize: CGSize
    let frameDurations: [TimeInterval]

    private let url: URL
    private let source: CGImageSource?
    private let cache = NSCache<NSNumber, NSImage>()
    private let lock = NSLock()

    init(
        resourceName: String,
        previewFrame: Int,
        onboardingFrame: Int,
        doorCreakFrame: Int,
        catChirpFrame: Int,
        sparkleFrame: Int
    ) {
        guard let url = ResourceBundle.current.url(
            forResource: resourceName,
            withExtension: "gif",
            subdirectory: "Animations"
        ) else {
            fatalError("Missing GIF resource: \(resourceName).gif")
        }

        self.url = url
        self.previewFrame = previewFrame
        self.onboardingFrame = onboardingFrame
        self.doorCreakFrame = doorCreakFrame
        self.catChirpFrame = catChirpFrame
        self.sparkleFrame = sparkleFrame

        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        self.source = source
        self.frameCount = source.map(CGImageSourceGetCount) ?? 1
        if let source,
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
           height > 0 {
            self.pixelSize = CGSize(width: width, height: height)
        } else {
            self.pixelSize = CGSize(width: 1, height: 1)
        }

        var totalDuration: TimeInterval = 0
        var resolvedFrameDurations: [TimeInterval] = []
        if let source {
            for index in 0..<CGImageSourceGetCount(source) {
                let frameDuration = Self.frameDuration(source: source, index: index)
                totalDuration += frameDuration
                resolvedFrameDurations.append(frameDuration)
            }
        }
        self.duration = max(totalDuration, 0.1)
        self.frameDurations = resolvedFrameDurations
    }

    var animatedImage: NSImage? {
        NSImage(contentsOf: url)
    }

    var aspectRatio: CGFloat {
        pixelSize.width / max(pixelSize.height, 1)
    }

    var overlayDisplaySize: CGSize {
        pixelSize
    }

    var previewDisplaySize: CGSize {
        scaledSize(multiplier: 0.33)
    }

    var onboardingDisplaySize: CGSize {
        scaledSize(multiplier: 0.45)
    }

    func size(forHeight height: CGFloat) -> CGSize {
        CGSize(width: height * aspectRatio, height: height)
    }

    func size(forWidth width: CGFloat) -> CGSize {
        CGSize(width: width, height: width / max(aspectRatio, 0.001))
    }

    func scaledSize(multiplier: CGFloat) -> CGSize {
        CGSize(
            width: pixelSize.width * multiplier,
            height: pixelSize.height * multiplier
        )
    }

    func image(at index: Int) -> NSImage? {
        let resolvedIndex = max(0, min(frameCount - 1, index))
        let key = NSNumber(value: resolvedIndex)

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard
            let source,
            let cgImage = CGImageSourceCreateImageAtIndex(source, resolvedIndex, nil)
        else {
            return animatedImage
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }

    var doorCreakDelay: Duration {
        .milliseconds(Int((Double(doorCreakFrame) / Double(max(frameCount, 1))) * duration * 1000))
    }

    var catChirpDelay: Duration {
        .milliseconds(Int((Double(catChirpFrame) / Double(max(frameCount, 1))) * duration * 1000))
    }

    var sparkleDelay: Duration {
        .milliseconds(Int((Double(sparkleFrame) / Double(max(frameCount, 1))) * duration * 1000))
    }

    var dismissDelay: Duration {
        .milliseconds(Int(duration * 1000) + 250)
    }

    var lastFrameIndex: Int {
        max(frameCount - 1, 0)
    }

    func frameDelay(at index: Int) -> Duration {
        guard frameDurations.isEmpty == false else {
            return .milliseconds(40)
        }
        let resolvedIndex = max(0, min(frameDurations.count - 1, index))
        return .milliseconds(Int(frameDurations[resolvedIndex] * 1000))
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.04
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.04
        return delay < 0.011 ? 0.04 : delay
    }
}
