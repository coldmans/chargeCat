import Foundation

struct LicensePreferencesStore {
    private let defaults: UserDefaults
    private let stateKey = "license.state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LicenseState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(LicenseState.self, from: data)
        else {
            return .free
        }
        return state.refreshedWarning()
    }

    func save(_ state: LicenseState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    func clear() {
        defaults.removeObject(forKey: stateKey)
    }
}
