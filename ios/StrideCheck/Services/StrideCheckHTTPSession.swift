import Foundation

// MARK: - Allowed hosts

/// Returns true when StrideCheck is permitted to accept a proxy-issued TLS chain for `rawHost`.
private func strideCheckHostAllowed(_ rawHost: String) -> Bool {
    let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    if host.isEmpty { return false }
    if host == "api.zippopotam.us" || host.hasSuffix(".zippopotam.us") { return true }
    if host == "api.weather.gov"   || host.hasSuffix(".weather.gov")   { return true }
    if host == "api.open-meteo.com"
        || host == "air-quality-api.open-meteo.com"
        || host.hasSuffix(".open-meteo.com")       { return true }
    if host == "api.crimeometer.com"               { return true }
    if host == "api.ouraring.com"                  { return true }
    if host == "api.prod.whoop.com"                { return true }
    if host == "www.strava.com" || host == "strava.com" { return true }
    if host == "connect.garmin.com"
        || host == "diauth.garmin.com"
        || host == "apis.garmin.com"               { return true }
    if host == "arcgis.com" || host.hasSuffix(".arcgis.com") { return true }
    if host.hasSuffix(".dot.gov")                  { return true }
    if host.hasSuffix("wsdot.wa.gov")              { return true }
    if host == "api.open-elevation.com"            { return true }
    return false
}

// MARK: - Shared session

/// Shared `URLSession` for StrideCheck API calls.
///
/// **Timeout**: 20 s per request — long enough for NWS / Open-Meteo cold starts, short enough to
/// show an error promptly on a flaky connection.
///
/// **TLS delegate** (debug builds only): accepts proxy-issued chains (e.g. Zscaler / Charles) for
/// allowlisted hosts. Stripped from release builds via `#if DEBUG` so production traffic always uses
/// the system's default certificate validation.
enum StrideCheckHTTPSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        config.httpShouldSetCookies = false
        #if DEBUG
        return URLSession(configuration: config, delegate: ProxyTrustDelegate.shared, delegateQueue: nil)
        #else
        return URLSession(configuration: config)
        #endif
    }()
}

// MARK: - Retry helper

extension URLSession {
    /// Fetches `url` retrying up to `maxAttempts` times with exponential back-off on transient errors.
    ///
    /// Back-off schedule (seconds): 0.5 → 1.0 → 2.0 (for maxAttempts = 3).
    /// Non-retryable: cancellation, client auth failures (`userAuthenticationRequired`).
    func dataWithRetry(
        from url: URL,
        maxAttempts: Int = 3
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        var delay: TimeInterval = 0.5
        while true {
            attempt += 1
            do {
                let result = try await data(from: url)
                return result
            } catch {
                if attempt >= maxAttempts { throw error }
                if error is CancellationError { throw error }
                if let urlErr = error as? URLError, urlErr.code == .cancelled { throw error }
                if let urlErr = error as? URLError, urlErr.code == .userAuthenticationRequired { throw error }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, 4)
            }
        }
    }

    /// Fetches `request` retrying up to `maxAttempts` times with exponential back-off on transient errors.
    ///
    /// Non-retryable: cancellation, client auth failures (`userAuthenticationRequired`), same as `dataWithRetry(from:)`.
    func dataWithRetry(
        for request: URLRequest,
        maxAttempts: Int = 3
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        var delay: TimeInterval = 0.5
        while true {
            attempt += 1
            do {
                let result = try await data(for: request)
                return result
            } catch {
                if attempt >= maxAttempts { throw error }
                if error is CancellationError { throw error }
                if let urlErr = error as? URLError, urlErr.code == .cancelled { throw error }
                if let urlErr = error as? URLError, urlErr.code == .userAuthenticationRequired { throw error }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, 4)
            }
        }
    }
}

// MARK: - Debug-only proxy trust delegate

#if DEBUG
private final class ProxyTrustDelegate: NSObject, URLSessionTaskDelegate, URLSessionDelegate {
    static let shared = ProxyTrustDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleServerTrust(challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleServerTrust(challenge, completionHandler: completionHandler)
    }

    private func handleServerTrust(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              strideCheckHostAllowed(challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
#endif
