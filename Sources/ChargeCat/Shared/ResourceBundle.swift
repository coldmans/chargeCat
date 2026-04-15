import Foundation

enum ResourceBundle {
    static let current: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }()
}
