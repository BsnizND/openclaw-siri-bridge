import Foundation
import HealthKit
import WatchKit

@MainActor
final class GolfWorkoutController: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var lastError: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?

    func start() async -> Bool {
        guard !isActive else { return true }
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "Health data is not available on this Watch."
            WKInterfaceDevice.current().play(.failure)
            return false
        }

        do {
            try await requestWorkoutPermission()

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .golf
            configuration.locationType = .outdoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            self.session = session

            session.prepare()
            session.startActivity(with: Date())
            isActive = true
            lastError = nil
            return true
        } catch {
            self.session = nil
            isActive = false
            lastError = error.localizedDescription
            WKInterfaceDevice.current().play(.failure)
            return false
        }
    }

    func stop() {
        session?.end()
        session = nil
        isActive = false
        WKInterfaceDevice.current().play(.stop)
    }

    private func requestWorkoutPermission() async throws {
        let workoutType = HKObjectType.workoutType()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [workoutType], read: [workoutType]) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: GolfWorkoutError.permissionDenied)
                }
            }
        }
    }
}

extension GolfWorkoutController: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            guard self.session === workoutSession else { return }
            switch toState {
            case .running, .prepared:
                self.isActive = true
                self.lastError = nil
            case .ended, .stopped:
                self.session = nil
                self.isActive = false
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.session === workoutSession else { return }
            self.session = nil
            self.isActive = false
            self.lastError = error.localizedDescription
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

private enum GolfWorkoutError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Workout permission is required for Golf Mode."
        }
    }
}
