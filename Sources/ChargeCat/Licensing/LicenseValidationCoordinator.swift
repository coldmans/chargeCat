import Foundation

@MainActor
enum ValidationAttemptResult {
    case success(LicenseState)
    case explicitFailure(LicenseState)
    case transientFailure(message: String, retryAfter: TimeInterval?)
}

@MainActor
final class LicenseValidationCoordinator {
    private let now: () -> Date
    private let minimumValidateInterval: TimeInterval
    private let backoffSchedule: [TimeInterval]

    private var inFlightTask: Task<LicenseState, Never>?
    private var consecutiveTransientFailures = 0
    private var lastAttemptAt: Date?
    private var nextRetryAt: Date?

    init(
        now: @escaping () -> Date = Date.init,
        minimumValidateInterval: TimeInterval = 30,
        backoffSchedule: [TimeInterval] = [60, 5 * 60, 15 * 60, 60 * 60]
    ) {
        self.now = now
        self.minimumValidateInterval = minimumValidateInterval
        self.backoffSchedule = backoffSchedule
    }

    func validate(
        force: Bool,
        currentState: LicenseState,
        execute: @escaping () async -> ValidationAttemptResult
    ) async -> LicenseState {
        if let inFlightTask {
            return await inFlightTask.value
        }

        let startedAt = now()
        if force == false {
            if let lastAttemptAt,
               startedAt.timeIntervalSince(lastAttemptAt) < minimumValidateInterval {
                return currentState.refreshedWarning(now: startedAt)
            }

            if let nextRetryAt, startedAt < nextRetryAt {
                return transientState(
                    from: currentState,
                    message: currentState.lastErrorMessage,
                    attemptAt: lastAttemptAt ?? currentState.lastValidationAttemptAt ?? startedAt,
                    nextRetryAt: nextRetryAt
                )
            }
        }

        let task = Task<LicenseState, Never> { [startedAt] in
            let result = await execute()
            return self.finishValidation(
                result,
                currentState: currentState,
                attemptAt: startedAt
            )
        }
        inFlightTask = task
        return await task.value
    }

    private func finishValidation(
        _ result: ValidationAttemptResult,
        currentState: LicenseState,
        attemptAt: Date
    ) -> LicenseState {
        defer { inFlightTask = nil }

        switch result {
        case let .success(state):
            consecutiveTransientFailures = 0
            lastAttemptAt = attemptAt
            nextRetryAt = nil

            var nextState = state
            nextState.lastValidationAttemptAt = attemptAt
            nextState.nextRetryAt = nil
            nextState.lastErrorMessage = nil
            return nextState.refreshedWarning(now: attemptAt)

        case let .explicitFailure(state):
            consecutiveTransientFailures = 0
            lastAttemptAt = attemptAt
            nextRetryAt = nil

            var nextState = state
            nextState.lastValidationAttemptAt = attemptAt
            nextState.nextRetryAt = nil
            return nextState.refreshedWarning(now: attemptAt)

        case let .transientFailure(message, retryAfter):
            consecutiveTransientFailures += 1
            lastAttemptAt = attemptAt

            let delay = retryAfter ?? scheduledBackoff(for: consecutiveTransientFailures)
            let retryDate = attemptAt.addingTimeInterval(delay)
            nextRetryAt = retryDate

            return transientState(
                from: currentState,
                message: message,
                attemptAt: attemptAt,
                nextRetryAt: retryDate
            )
        }
    }

    private func scheduledBackoff(for failureCount: Int) -> TimeInterval {
        backoffSchedule[min(max(failureCount - 1, 0), backoffSchedule.count - 1)]
    }

    private func transientState(
        from currentState: LicenseState,
        message: String?,
        attemptAt: Date,
        nextRetryAt: Date
    ) -> LicenseState {
        var nextState = currentState
        nextState.lastValidationAttemptAt = attemptAt
        nextState.nextRetryAt = nextRetryAt
        nextState.lastErrorMessage = message

        if currentState.status.allowsProAccess || currentState.lastKnownTier == .pro {
            nextState.status = .proCached
            nextState.lastKnownTier = .pro
        }

        return nextState.refreshedWarning(now: attemptAt)
    }
}
