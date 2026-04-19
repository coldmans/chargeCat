import Foundation
import IOKit

/// macOS가 관리하는 충전 상한(시스템 설정 > 배터리 > "배터리 수명 관리" 등)을 읽어온다.
/// IOKit의 AppleSmartBattery 서비스 프로퍼티는 공식 문서화되어 있지 않으므로
/// 알려진 키 후보들을 순차적으로 시도하고, 합리적 범위(50~100)에 들 때만 반환한다.
enum ChargeLimitReader {
    /// 후보 키 경로. 배열의 각 항목은 점(.)으로 중첩 딕셔너리를 탐색한다.
    private static let candidateKeyPaths: [[String]] = [
        ["ChargeLimit"],
        ["AppleRawChargeLimit"],
        ["AppleChargeLimit"],
        ["BatteryData", "ChargeLimit"],
        ["BatteryData", "ChargingVoltageSecondaryStatePOR"]
    ]

    static func readSystemChargeLimit() -> Int? {
        guard let props = copyBatteryProperties() else {
            return nil
        }

        for path in candidateKeyPaths {
            if let value = lookup(path: path, in: props),
               let limit = normalize(value) {
                return limit
            }
        }
        return nil
    }

    private static func copyBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let dict = unmanaged?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func lookup(path: [String], in root: [String: Any]) -> Any? {
        var current: Any = root
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    private static func normalize(_ raw: Any) -> Int? {
        let value: Int
        switch raw {
        case let intValue as Int:
            value = intValue
        case let doubleValue as Double:
            value = Int(doubleValue.rounded())
        case let numberValue as NSNumber:
            value = numberValue.intValue
        default:
            return nil
        }

        guard value >= ChargeTarget.minimum, value <= ChargeTarget.maximum else {
            return nil
        }
        return value
    }
}
