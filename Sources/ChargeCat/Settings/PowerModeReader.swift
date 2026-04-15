import Foundation

enum PowerMode: String, Equatable {
    case lowPower
    case automatic
    case highPower
    case unknown

    var title: String {
        switch self {
        case .lowPower:
            return "Low Power"
        case .automatic:
            return "Automatic"
        case .highPower:
            return "High Power"
        case .unknown:
            return "Unknown"
        }
    }
}

enum PowerModeReader {
    static func readCurrentMode(isPluggedIn: Bool?) -> PowerMode {
        let processInfoLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let settings = readPowerModeSettings()

        let selectedMode: PowerMode?
        if let isPluggedIn {
            selectedMode = isPluggedIn ? settings.acPower : settings.batteryPower
        } else {
            selectedMode = settings.current
        }

        if processInfoLowPower {
            return .lowPower
        }

        return selectedMode ?? .unknown
    }

    private static func readPowerModeSettings() -> (
        batteryPower: PowerMode?,
        acPower: PowerMode?,
        current: PowerMode?
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "custom"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return (nil, nil, nil)
        }

        process.waitUntilExit()

        guard
            process.terminationStatus == 0,
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        else {
            return (nil, nil, nil)
        }

        var section: String?
        var batteryPower: PowerMode?
        var acPower: PowerMode?

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.isEmpty == false else { continue }

            if line == "Battery Power:" {
                section = "battery"
                continue
            }

            if line == "AC Power:" {
                section = "ac"
                continue
            }

            guard line.hasPrefix("powermode") else { continue }
            let components = line.split(whereSeparator: \.isWhitespace)
            guard let last = components.last, let rawValue = Int(last) else { continue }

            let mode = decode(rawValue)
            if section == "battery" {
                batteryPower = mode
            } else if section == "ac" {
                acPower = mode
            }
        }

        return (batteryPower, acPower, nil)
    }

    private static func decode(_ rawValue: Int) -> PowerMode {
        switch rawValue {
        case 0:
            return .lowPower
        case 1:
            return .automatic
        case 2:
            return .highPower
        default:
            return .unknown
        }
    }
}
