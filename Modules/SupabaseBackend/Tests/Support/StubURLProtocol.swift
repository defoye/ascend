import Foundation

/// A `URLProtocol` that intercepts every request made through a `URLSession`
/// configured with it, so adapter tests can drive `SupabaseBackend`'s
/// PostgREST calls against canned responses/errors instead of a live project.
///
/// State is process-global (URLProtocol instances are created by `URLSession`,
/// not by the test, so there is no per-instance injection point). Every suite
/// that uses this MUST be `.serialized` — swift-testing runs `@Test`s in
/// parallel by default, and a shared global handler would otherwise race.
/// Call `reset(_:)` at the start of each test to install that test's handler
/// and clear captured requests.
final class StubURLProtocol: URLProtocol {
    /// Produces the canned outcome for a request: either an HTTP response with
    /// a body, or a transport `Error` (e.g. `URLError`) to simulate offline.
    typealias Handler = @Sendable (URLRequest) -> Result<(HTTPURLResponse, Data), Error>

    private struct State {
        var handler: Handler?
        var capturedRequests: [URLRequest] = []
    }

    nonisolated(unsafe) private static var state = State()
    private static let lock = NSLock()

    static func reset(_ handler: @escaping Handler) {
        lock.withLock { state = State(handler: handler) }
    }

    static var capturedRequests: [URLRequest] {
        lock.withLock { state.capturedRequests }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler: Handler? = Self.lock.withLock {
            Self.state.capturedRequests.append(request)
            return Self.state.handler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch handler(request) {
        case let .success((response, data)):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    // MARK: - Test helpers

    /// A `URLSession` that routes all traffic through this stub.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func httpResponse(_ request: URLRequest, status: Int, body: Data = Data()) -> Result<(HTTPURLResponse, Data), Error> {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return .success((response, body))
    }
}
