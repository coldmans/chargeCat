import Foundation

struct BatterySnapshot: Equatable {
    let level: Int
    let isPluggedIn: Bool
    let isCharging: Bool

    var powerText: String {
        if isPluggedIn && level >= 99 && isCharging == false {
            return "Fully Charged"
        }
        if isCharging {
            return "Charging"
        }
        if isPluggedIn {
            return "Power Connected"
        }
        return "On Battery"
    }
}
