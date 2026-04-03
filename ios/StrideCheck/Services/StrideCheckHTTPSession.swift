import Foundation

/// Hosts StrideCheck calls over HTTPS; must match `URL.host` exactly (no wildcards).
private let strideCheckAllowedAPIHosts: Set<String> = [
    "api.open-meteo.com",
    "air-quality-api.open-meteo.com",
    "api.weather.gov",
    "api.zippopotam.us"
]

/// Shared `URLSession` for StrideCheck API calls when HTTPS is intercepted by SSL inspection (e.g. Zscaler).
///
/// **Security:** Only hosts used by this app are allowlisted. Trust is accepted in **Debug** builds
/// so you can develop behind SSL inspection. **Release** builds use system trust (install your org
/// root CA on the device, or ask IT to bypass inspection for these API hosts).
enum StrideCheckHTTPSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: Delegate.shared, delegateQueue: nil)
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
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard strideCheckAllowedAPIHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        #if DEBUG
        completionHandler(.useCredential, URLCredential(trust: trust))
        #else
        completionHandler(.performDefaultHandling, nil)
        #endif
    }
}
