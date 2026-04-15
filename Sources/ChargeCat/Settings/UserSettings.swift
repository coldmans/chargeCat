import Foundation

@MainActor
enum UserSettings {
    private static let defaults = UserDefaults.standard

    static var preferredSide: ScreenSide {
        get {
            guard let rawValue = defaults.string(forKey: "preferredSide"),
                  let side = ScreenSide(rawValue: rawValue)
            else {
                return .left
            }
            return side
        }
        set {
            defaults.set(newValue.rawValue, forKey: "preferredSide")
        }
    }

    static var soundEnabled: Bool {
        get {
            defaults.object(forKey: "soundEnabled") as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: "soundEnabled")
        }
    }

    static var autoMonitorEnabled: Bool {
        get {
            defaults.object(forKey: "autoMonitorEnabled") as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: "autoMonitorEnabled")
        }
    }

    static var launchAtLoginEnabled: Bool {
        get {
            defaults.object(forKey: "launchAtLoginEnabled") as? Bool ?? false
        }
        set {
            defaults.set(newValue, forKey: "launchAtLoginEnabled")
        }
    }

    static var hasCompletedOnboarding: Bool {
        get {
            defaults.object(forKey: "hasCompletedOnboarding") as? Bool ?? false
        }
        set {
            defaults.set(newValue, forKey: "hasCompletedOnboarding")
        }
    }
}
