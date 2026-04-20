import AppKit
import Foundation

enum OverlayAssetMediaType: String, Codable {
    case gif
    case video
}

struct OverlayAssetDownloadAuthorization {
    let licenseKey: String
    let instanceId: String
}

enum OverlayAssetSoundProfile: String, Codable {
    case silent
    case doorCat

    var doorCreakDelay: Duration? {
        switch self {
        case .silent:
            return nil
        case .doorCat:
            return .milliseconds(80)
        }
    }

    var catChirpDelay: Duration? {
        switch self {
        case .silent:
            return nil
        case .doorCat:
            return .milliseconds(950)
        }
    }
}

struct OverlayAssetCatalogEntry: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let mediaType: OverlayAssetMediaType
    let downloadURL: URL
    let systemImage: String?
    let soundProfile: OverlayAssetSoundProfile
    let previewHeight: Double?
    let overlayHeight: Double?
    let recommendedEvent: OverlayEventKind?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case mediaType
        case downloadURL
        case systemImage
        case soundProfile
        case previewHeight
        case overlayHeight
        case recommendedEvent
    }

    init(
        id: String,
        title: String,
        mediaType: OverlayAssetMediaType,
        downloadURL: URL,
        systemImage: String?,
        soundProfile: OverlayAssetSoundProfile,
        previewHeight: Double?,
        overlayHeight: Double?,
        recommendedEvent: OverlayEventKind?
    ) {
        self.id = id
        self.title = title
        self.mediaType = mediaType
        self.downloadURL = downloadURL
        self.systemImage = systemImage
        self.soundProfile = soundProfile
        self.previewHeight = previewHeight
        self.overlayHeight = overlayHeight
        self.recommendedEvent = recommendedEvent
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        mediaType = try container.decode(OverlayAssetMediaType.self, forKey: .mediaType)
        systemImage = try container.decodeIfPresent(String.self, forKey: .systemImage)
        soundProfile = try container.decodeIfPresent(OverlayAssetSoundProfile.self, forKey: .soundProfile) ?? .silent
        previewHeight = try container.decodeIfPresent(Double.self, forKey: .previewHeight)
        overlayHeight = try container.decodeIfPresent(Double.self, forKey: .overlayHeight)
        recommendedEvent = try container.decodeIfPresent(OverlayEventKind.self, forKey: .recommendedEvent)

        let rawURL = try container.decode(String.self, forKey: .downloadURL)
        guard let resolved = URL(string: rawURL) else {
            throw DecodingError.dataCorruptedError(
                forKey: .downloadURL,
                in: container,
                debugDescription: "downloadURL must be an absolute URL"
            )
        }
        downloadURL = resolved
    }
}

struct DownloadedOverlayAssetRecord: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let mediaType: OverlayAssetMediaType
    let localFilename: String
    let systemImage: String?
    let soundProfile: OverlayAssetSoundProfile
    let previewHeight: Double?
    let overlayHeight: Double?
    let recommendedEvent: OverlayEventKind?
    let installedAt: Date
}

struct InstalledOverlayAsset: Identifiable, Equatable {
    let reference: OverlayAssetReference
    let bundledAsset: OverlayAnimationAsset?
    let customTitle: String?
    let systemImage: String
    let overlayDisplaySize: CGSize
    let previewDisplaySize: CGSize
    let dismissDelay: Duration
    let previewImage: NSImage?
    let doorCreakDelay: Duration?
    let catChirpDelay: Duration?
    let gifAsset: GIFAsset?
    let videoAsset: VideoAsset?
    let isDownloaded: Bool
    let recommendedEvent: OverlayEventKind?

    var id: String { reference.id }

    static func == (lhs: InstalledOverlayAsset, rhs: InstalledOverlayAsset) -> Bool {
        lhs.reference == rhs.reference
    }
}

enum OverlayAssetLibraryError: LocalizedError {
    case notConfigured
    case catalogUnavailable
    case invalidCatalog
    case downloadFailed
    case localFileMissing

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The backend asset catalog is not configured yet."
        case .catalogUnavailable:
            return "Couldn't load the downloadable animation catalog right now."
        case .invalidCatalog:
            return "The backend returned an invalid animation catalog."
        case .downloadFailed:
            return "Couldn't download this animation right now."
        case .localFileMissing:
            return "This downloaded animation is missing from disk."
        }
    }
}

@MainActor
final class OverlayAssetLibrary {
    private struct AssetCatalogResponse: Decodable {
        let assets: [OverlayAssetCatalogEntry]
    }

    private let configuration: LicensingConfiguration
    private let fileManager: FileManager
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        configuration: LicensingConfiguration = .load(),
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.session = session
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadDownloadedAssets() -> [DownloadedOverlayAssetRecord] {
        guard let manifestURL,
              let data = try? Data(contentsOf: manifestURL),
              let records = try? decoder.decode([DownloadedOverlayAssetRecord].self, from: data)
        else {
            return []
        }
        return records
    }

    func fetchCatalog() async throws -> [OverlayAssetCatalogEntry] {
        guard let catalogURL = configuration.assetCatalogURL else {
            throw OverlayAssetLibraryError.notConfigured
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: catalogURL)
        } catch {
            throw OverlayAssetLibraryError.catalogUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw OverlayAssetLibraryError.catalogUnavailable
        }

        do {
            return try decoder.decode(AssetCatalogResponse.self, from: data).assets
        } catch {
            throw OverlayAssetLibraryError.invalidCatalog
        }
    }

    func download(
        _ asset: OverlayAssetCatalogEntry,
        authorization: OverlayAssetDownloadAuthorization,
        downloadedAssets: [DownloadedOverlayAssetRecord]
    ) async throws -> [DownloadedOverlayAssetRecord] {
        try ensureStorageDirectories()

        let (temporaryURL, response): (URL, URLResponse)
        var request = URLRequest(url: asset.downloadURL)
        request.setValue(authorization.licenseKey, forHTTPHeaderField: "X-ChargeCat-License-Key")
        request.setValue(authorization.instanceId, forHTTPHeaderField: "X-ChargeCat-Instance-ID")

        do {
            (temporaryURL, response) = try await session.download(for: request)
        } catch {
            throw OverlayAssetLibraryError.downloadFailed
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw OverlayAssetLibraryError.downloadFailed
        }

        let fileExtension = asset.downloadURL.pathExtension.isEmpty
            ? fallbackExtension(for: asset.mediaType)
            : asset.downloadURL.pathExtension
        let localFilename = "\(asset.id).\(fileExtension)"
        let destinationURL = assetsDirectoryURL.appendingPathComponent(localFilename)

        try? fileManager.removeItem(at: destinationURL)
        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            throw OverlayAssetLibraryError.downloadFailed
        }

        var next = downloadedAssets.filter { $0.id != asset.id }
        next.append(
            DownloadedOverlayAssetRecord(
                id: asset.id,
                title: asset.title,
                mediaType: asset.mediaType,
                localFilename: localFilename,
                systemImage: asset.systemImage,
                soundProfile: asset.soundProfile,
                previewHeight: asset.previewHeight,
                overlayHeight: asset.overlayHeight,
                recommendedEvent: asset.recommendedEvent,
                installedAt: Date()
            )
        )
        try saveDownloadedAssets(next)
        return next.sorted { $0.installedAt < $1.installedAt }
    }

    func deleteDownloadedAsset(
        id: String,
        downloadedAssets: [DownloadedOverlayAssetRecord]
    ) throws -> [DownloadedOverlayAssetRecord] {
        guard let record = downloadedAssets.first(where: { $0.id == id }) else {
            return downloadedAssets
        }

        let localURL = assetsDirectoryURL.appendingPathComponent(record.localFilename)
        try? fileManager.removeItem(at: localURL)

        let next = downloadedAssets.filter { $0.id != id }
        try saveDownloadedAssets(next)
        return next
    }

    func installedAssets(
        downloadedAssets: [DownloadedOverlayAssetRecord]
    ) -> [InstalledOverlayAsset] {
        var assets = OverlayAnimationAsset.allCases.map { resolveBuiltIn($0) }
        assets.append(contentsOf: downloadedAssets.compactMap(resolveDownloaded))
        return assets
    }

    func resolve(
        reference: OverlayAssetReference,
        downloadedAssets: [DownloadedOverlayAssetRecord]
    ) -> InstalledOverlayAsset? {
        if let bundled = reference.bundledAsset {
            return resolveBuiltIn(bundled)
        }

        guard reference.source == .downloaded,
              let record = downloadedAssets.first(where: { $0.id == reference.value })
        else {
            return nil
        }
        return resolveDownloaded(record)
    }

    private var applicationSupportURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("ChargeCat", isDirectory: true)
    }

    private var assetsDirectoryURL: URL {
        applicationSupportURL.appendingPathComponent("DownloadedOverlayAssets", isDirectory: true)
    }

    private var manifestURL: URL? {
        applicationSupportURL.appendingPathComponent("downloaded-assets.json")
    }

    private func ensureStorageDirectories() throws {
        try fileManager.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.createDirectory(
            at: assetsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func saveDownloadedAssets(_ assets: [DownloadedOverlayAssetRecord]) throws {
        guard let manifestURL else { return }
        try ensureStorageDirectories()
        let data = try encoder.encode(assets)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private func fallbackExtension(for mediaType: OverlayAssetMediaType) -> String {
        switch mediaType {
        case .gif:
            return "gif"
        case .video:
            return "mov"
        }
    }

    private func resolveBuiltIn(_ asset: OverlayAnimationAsset) -> InstalledOverlayAsset {
        InstalledOverlayAsset(
            reference: .bundled(asset),
            bundledAsset: asset,
            customTitle: nil,
            systemImage: asset.systemImage,
            overlayDisplaySize: asset.overlayDisplaySize,
            previewDisplaySize: asset.previewDisplaySize,
            dismissDelay: asset.dismissDelay,
            previewImage: asset.previewImage,
            doorCreakDelay: asset.doorCreakDelay,
            catChirpDelay: asset.catChirpDelay,
            gifAsset: asset.gifAsset,
            videoAsset: asset.videoAsset,
            isDownloaded: false,
            recommendedEvent: asset == .catDoor ? .chargeStarted : .fullyCharged
        )
    }

    private func resolveDownloaded(_ record: DownloadedOverlayAssetRecord) -> InstalledOverlayAsset? {
        let localURL = assetsDirectoryURL.appendingPathComponent(record.localFilename)
        guard fileManager.fileExists(atPath: localURL.path) else { return nil }

        switch record.mediaType {
        case .gif:
            let gifAsset = GIFAsset(
                url: localURL,
                previewFrame: 0,
                onboardingFrame: 0,
                doorCreakFrame: 0,
                catChirpFrame: 0,
                sparkleFrame: 0
            )
            return InstalledOverlayAsset(
                reference: OverlayAssetReference(source: .downloaded, value: record.id),
                bundledAsset: nil,
                customTitle: record.title,
                systemImage: record.systemImage ?? "square.and.arrow.down",
                overlayDisplaySize: gifAsset.size(forHeight: CGFloat(record.overlayHeight ?? 240)),
                previewDisplaySize: gifAsset.size(forHeight: CGFloat(record.previewHeight ?? 96)),
                dismissDelay: gifAsset.dismissDelay,
                previewImage: gifAsset.image(at: gifAsset.previewFrame),
                doorCreakDelay: record.soundProfile.doorCreakDelay,
                catChirpDelay: record.soundProfile.catChirpDelay,
                gifAsset: gifAsset,
                videoAsset: nil,
                isDownloaded: true,
                recommendedEvent: record.recommendedEvent
            )
        case .video:
            let videoAsset = VideoAsset(url: localURL)
            return InstalledOverlayAsset(
                reference: OverlayAssetReference(source: .downloaded, value: record.id),
                bundledAsset: nil,
                customTitle: record.title,
                systemImage: record.systemImage ?? "square.and.arrow.down",
                overlayDisplaySize: videoAsset.size(forHeight: CGFloat(record.overlayHeight ?? 260)),
                previewDisplaySize: videoAsset.size(forHeight: CGFloat(record.previewHeight ?? 96)),
                dismissDelay: videoAsset.dismissDelay,
                previewImage: videoAsset.previewImage,
                doorCreakDelay: record.soundProfile.doorCreakDelay,
                catChirpDelay: record.soundProfile.catChirpDelay,
                gifAsset: nil,
                videoAsset: videoAsset,
                isDownloaded: true,
                recommendedEvent: record.recommendedEvent
            )
        }
    }
}
