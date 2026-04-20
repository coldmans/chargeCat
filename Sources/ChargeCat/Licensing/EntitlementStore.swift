import Foundation
import Observation

@MainActor
@Observable
final class EntitlementStore {
    var state: LicenseState

    private let preferences: LicensePreferencesStore

    init(
        initialState: LicenseState,
        preferences: LicensePreferencesStore = LicensePreferencesStore()
    ) {
        self.state = initialState
        self.preferences = preferences
    }

    func apply(_ newState: LicenseState) {
        let refreshed = newState.refreshedWarning()
        state = refreshed
        preferences.save(refreshed)
    }

    func reset() {
        apply(.free)
    }

    func isEnabled(_ feature: ProFeature) -> Bool {
        switch feature {
        case .animationCustomization, .downloadableAssets:
            return state.status.allowsProAccess
        }
    }
}
