import AppKit
import AVFoundation
import CoreGraphics
import Foundation

enum OverlayAnimationAsset: String, CaseIterable, Identifiable {
    case catDoor
    case fullBelly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catDoor:
            return "Door Cat"
        case .fullBelly:
            return "Full Belly"
        }
    }

    var systemImage: String {
        switch self {
        case .catDoor:
            return "door.left.hand.open"
        case .fullBelly:
            return "play.rectangle.fill"
        }
    }

    var overlayDisplaySize: CGSize {
        switch self {
        case .catDoor:
            return VideoAsset.doorCatHD.size(forHeight: 300)
        case .fullBelly:
            return VideoAsset.fullBelly.size(forHeight: 240)
        }
    }

    var previewDisplaySize: CGSize {
        switch self {
        case .catDoor:
            return VideoAsset.doorCatHD.size(forHeight: 104)
        case .fullBelly:
            return VideoAsset.fullBelly.size(forHeight: 96)
        }
    }

    var dismissDelay: Duration {
        switch self {
        case .catDoor:
            return VideoAsset.doorCatHD.dismissDelay
        case .fullBelly:
            return VideoAsset.fullBelly.dismissDelay
        }
    }

    var previewImage: NSImage? {
        switch self {
        case .catDoor:
            return VideoAsset.doorCatHD.previewImage
        case .fullBelly:
            return VideoAsset.fullBelly.previewImage
        }
    }

    var doorCreakDelay: Duration? {
        switch self {
        case .catDoor:
            return .milliseconds(80)
        case .fullBelly:
            return nil
        }
    }

    var catChirpDelay: Duration? {
        switch self {
        case .catDoor:
            return .milliseconds(950)
        case .fullBelly:
            return nil
        }
    }

    var gifAsset: GIFAsset? {
        switch self {
        case .catDoor:
            return nil
        case .fullBelly:
            return nil
        }
    }

    var videoAsset: VideoAsset? {
        switch self {
        case .catDoor:
            return .doorCatHD
        case .fullBelly:
            return .fullBelly
        }
    }
}

final class VideoAsset: @unchecked Sendable {
    static let doorCatHD = VideoAsset(resourceName: "door-cat-hd", fileExtension: "mov")
    static let fullBelly = VideoAsset(resourceName: "full-belly", fileExtension: "mov")

    let duration: TimeInterval
    let pixelSize: CGSize
    let resourceKey: String

    private let url: URL
    private let previewFrameCache = NSCache<NSString, NSImage>()

    init(resourceName: String, fileExtension: String = "mp4") {
        guard let url = ResourceBundle.resourceURL(
            forResource: resourceName,
            withExtension: fileExtension,
            subdirectory: "Animations"
        ) else {
            fatalError("Missing video resource: \(resourceName).\(fileExtension)")
        }

        self.url = url
        self.resourceKey = url.absoluteString

        let asset = AVURLAsset(url: url)
        self.duration = max(asset.duration.seconds, 0.1)

        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            self.pixelSize = CGSize(
                width: abs(transformed.width),
                height: abs(transformed.height)
            )
        } else {
            self.pixelSize = CGSize(width: 1, height: 1)
        }
    }

    var playerItem: AVPlayerItem {
        AVPlayerItem(url: url)
    }

    var previewImage: NSImage? {
        image(at: .zero)
    }

    var dismissDelay: Duration {
        .milliseconds(Int(duration * 1000) + 250)
    }

    var aspectRatio: CGFloat {
        pixelSize.width / max(pixelSize.height, 1)
    }

    func size(forHeight height: CGFloat) -> CGSize {
        CGSize(width: height * aspectRatio, height: height)
    }

    func image(at time: CMTime) -> NSImage? {
        let cacheKey = "\(time.seconds)" as NSString
        if let cached = previewFrameCache.object(forKey: cacheKey) {
            return cached
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        previewFrameCache.setObject(image, forKey: cacheKey)
        return image
    }
}
