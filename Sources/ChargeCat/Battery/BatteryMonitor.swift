import Foundation
import IOKit.ps

@MainActor
final class BatteryMonitor {
    private weak var model: AppModel?
    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?
    private var previousSnapshot: BatterySnapshot?

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        stop()
        poll(reason: "initial read")

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource(Self.powerSourceChanged, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll(reason: "timer fallback")
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            self.runLoopSource = nil
        }
    }

    private func poll(reason: String) {
        let snapshot = Self.readSystemBattery()
        model?.updateBattery(snapshot)
        model?.refreshSystemChargeLimit()

        guard let model, let snapshot else {
            previousSnapshot = snapshot
            return
        }

        defer { previousSnapshot = snapshot }

        guard model.autoMonitorEnabled, let previousSnapshot else {
            return
        }

        // Unplug 감지 → throttle 리셋해서 빠른 재연결도 감지 가능
        if previousSnapshot.isPluggedIn && snapshot.isPluggedIn == false {
            model.resetTriggerHistory()
        }

        if isChargeStarted(from: previousSnapshot, to: snapshot) {
            model.trigger(.chargeStarted, level: snapshot.level, source: "system")
        }

        if isFullyCharged(from: previousSnapshot, to: snapshot, target: model.effectiveChargeTarget) {
            model.trigger(.fullyCharged, level: snapshot.level, source: "system")
        }
    }

    private func isChargeStarted(from previous: BatterySnapshot, to current: BatterySnapshot) -> Bool {
        // 플러그 상태 전환(false→true)만 트리거 조건으로 사용.
        // isCharging 토글(100% 도달 후 재충전 등)은 무시.
        return previous.isPluggedIn == false && current.isPluggedIn
    }

    private func isFullyCharged(from previous: BatterySnapshot, to current: BatterySnapshot, target: Int) -> Bool {
        // 사용자 지정 완충 기준(또는 시스템 상한) 도달 시점만 감지.
        // target 미만에서 target 이상으로 넘어가는 순간을 캡쳐하므로,
        // 이미 target 이상으로 꽂힌 상태에서는 트리거하지 않는다.
        return previous.level < target && current.level >= target && current.isPluggedIn
    }

    private static let powerSourceChanged: IOPowerSourceCallbackType = { context in
        guard let context else { return }
        let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in
            monitor.poll(reason: "power source callback")
        }
    }

    private static func readSystemBattery() -> BatterySnapshot? {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as Array

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
                let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
                maxCapacity > 0
            else {
                continue
            }

            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String ?? ""
            let level = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())

            return BatterySnapshot(
                level: level,
                isPluggedIn: powerSourceState == kIOPSACPowerValue,
                isCharging: isCharging
            )
        }

        return nil
    }
}
