import Foundation

/// Hosts StrideCheck calls over HTTPS. Matching is case-insensitive; Open-Meteo subdomains are allowed.
private func strideCheckHostAllowed(_ rawHost: String) -> Bool {
    let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    if host.isEmpty { return false }
    if host == "api.zippopotam.us" { return true }
    if host == "api.weather.gov" { return true }
    if host == "api.open-meteo.com" { return true }
    if host == "air-quality-api.open-meteo.com" { return true }
    if host.hasSuffix(".open-meteo.com") { return true }
    if host.hasSuffix(".weather.gov") { return true }
    if host.hasSuffix(".zippopotam.us") { return true }
    if host == "api.crimeometer.com" { return true }
    if host == "api.ouraring.com" { return true }
    if host == "api.prod.whoop.com" { return true }
    if host == "www.strava.com" { return true }
    if host == "strava.com" { return true }
    if host == "arcgis.com" || host.hasSuffix(".arcgis.com") { return true }
    if host.hasSuffix(".dot.gov") { return true }
    if host.hasSuffix("wsdot.wa.gov") { return true }
    return false
}

/// Shared `URLSession` for StrideCheck when HTTPS is intercepted by SSL inspection (e.g. Zscaler).
///
/// **Info.plist** relaxes ATS (Certificate Transparency + forward secrecy) only for our API domains.
/// This delegate then supplies `URLCredential(trust:)` so TLS can complete for the proxy-issued chain.
///
/// Only hostnames matched by `strideCheckHostAllowed` are accepted; all other TLS uses default evaluation.
enum StrideCheckHTTPSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 45
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration, delegate: Delegate.shared, delegateQueue: .main)
    }()
}

private final class Delegate: NSObject, URLSessionTaskDelegate, URLSessionDelegate {
    static let shared = Delegate()

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
        let method = challenge.protectionSpace.authenticationMethod
        guard method == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard strideCheckHostAllowed(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
