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

        guard let model, let snapshot else {
            previousSnapshot = snapshot
            return
        }

        defer { previousSnapshot = snapshot }

        guard model.autoMonitorEnabled, let previousSnapshot else {
            return
        }

        if isChargeStarted(from: previousSnapshot, to: snapshot) {
            model.trigger(.chargeStarted, level: snapshot.level, source: "system")
        }

        if isFullyCharged(from: previousSnapshot, to: snapshot) {
            model.trigger(.fullyCharged, level: snapshot.level, source: "system")
        }
    }

    private func isChargeStarted(from previous: BatterySnapshot, to current: BatterySnapshot) -> Bool {
        let powerWasConnected = previous.isPluggedIn == false && current.isPluggedIn
        let chargingJustStarted = previous.isCharging == false && current.isCharging
        return powerWasConnected || chargingJustStarted
    }

    private func isFullyCharged(from previous: BatterySnapshot, to current: BatterySnapshot) -> Bool {
        let reachedHundred = previous.level < 100 && current.level == 100 && current.isPluggedIn
        let chargingStoppedAtFull = previous.isCharging && current.isPluggedIn && current.isCharging == false && current.level >= 99
        return reachedHundred || chargingStoppedAtFull
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
