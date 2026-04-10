import Foundation

/// Serializes request dispatch to stay within a maximum requests-per-second rate.
/// Callers `await waitForSlot()` before each request; the actor sleeps as needed.
actor RateLimiter {
    private let minInterval: Duration
    private var lastFired: ContinuousClock.Instant = .now - .seconds(999)

    init(requestsPerSecond: Double) {
        minInterval = .nanoseconds(Int64(1_000_000_000.0 / requestsPerSecond))
    }

    func waitForSlot() async throws {
        let now = ContinuousClock.now
        let earliest = lastFired + minInterval
        if now < earliest {
            try await Task.sleep(until: earliest, clock: .continuous)
        }
        lastFired = ContinuousClock.now
    }
}
