import Foundation

@MainActor
enum UserSettings {
    private static let defaults = UserDefaults.standard

    static var appLanguage: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: "appLanguage"),
                  let language = AppLanguage(rawValue: rawValue)
            else {
                return .korean
            }
            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: "appLanguage")
        }
    }

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

    static var animationAssignments: [OverlayEventKind: OverlayAssetReference] {
        get {
            if let data = defaults.data(forKey: "animationAssignments"),
               let stored = try? JSONDecoder().decode([String: OverlayAssetReference].self, from: data) {
                var resolved: [OverlayEventKind: OverlayAssetReference] = [:]
                for event in OverlayEventKind.allCases {
                    resolved[event] = stored[event.rawValue] ?? migratedLegacyAssignment(for: event)
                }
                return resolved
            }

            return Dictionary(uniqueKeysWithValues: OverlayEventKind.allCases.map { event in
                (event, migratedLegacyAssignment(for: event))
            })
        }
        set {
            let encoded = Dictionary(uniqueKeysWithValues: newValue.map { key, value in
                (key.rawValue, value)
            })
            if let data = try? JSONEncoder().encode(encoded) {
                defaults.set(data, forKey: "animationAssignments")
            }
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

    /// 사용자가 수동으로 지정한 완충 기준(%). 50~100, 5% 단위.
    static var chargeTargetLevel: Int {
        get {
            let raw = defaults.object(forKey: "chargeTargetLevel") as? Int ?? 100
            return ChargeTarget.clamp(raw)
        }
        set {
            defaults.set(ChargeTarget.clamp(newValue), forKey: "chargeTargetLevel")
        }
    }
}

enum ChargeTarget {
    static let minimum = 50
    static let maximum = 100
    static let step = 5

    static func clamp(_ value: Int) -> Int {
        let bounded = max(minimum, min(maximum, value))
        let snapped = Int((Double(bounded - minimum) / Double(step)).rounded()) * step + minimum
        return max(minimum, min(maximum, snapped))
    }
}

private extension UserSettings {
    static func migratedLegacyAssignment(for event: OverlayEventKind) -> OverlayAssetReference {
        guard let rawValue = defaults.string(forKey: "selectedAnimationAsset") else {
            return event.defaultAssetReference
        }

        if rawValue == "doorCatHD" {
            defaults.removeObject(forKey: "selectedAnimationAsset")
            return event.defaultAssetReference
        }

        if event == .chargeStarted, let legacy = OverlayAnimationAsset(rawValue: rawValue) {
            return .bundled(legacy)
        }

        return event.defaultAssetReference
    }
}
