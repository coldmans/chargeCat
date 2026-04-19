import Foundation

enum ResourceBundle {
    static let current: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }()

    static func resourceURL(
        forResource resourceName: String,
        withExtension fileExtension: String,
        subdirectory: String? = nil
    ) -> URL? {
        if let subdirectory,
           let url = current.url(
               forResource: resourceName,
               withExtension: fileExtension,
               subdirectory: subdirectory
           ) {
            return url
        }

        return current.url(
            forResource: resourceName,
            withExtension: fileExtension
        )
    }
}
