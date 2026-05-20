//
//  DFURLProtocol.swift
//  EhPanda
//

import Foundation

class DFURLProtocol: URLProtocol {
    private var dfRequest: DFRequest?
    private var fallbackSession: URLSession?
    private var fallbackTask: URLSessionDataTask?
    static let requestIdentifier = "DomainFrontingRequest"

    override class func canonicalRequest(
        for request: URLRequest) -> URLRequest { request }
    override class func canInit(with request: URLRequest) -> Bool {
        if property(forKey: requestIdentifier, in: request) != nil {
            Logger.error("URLRequest has been initialized.")
            return false
        }
        if !["http", "https"].contains(request.url?.scheme) {
            let scheme = request.url?.scheme ?? "nil"
            Logger.error("URL scheme \"\(scheme)\" is not supported.")
            return false
        }
        return true
    }

    override func startLoading() {
        dfRequest = DFRequest(request, delegate: self)
        let request = request as? NSMutableURLRequest
        DFURLProtocol.setProperty(
            true, forKey: DFURLProtocol.requestIdentifier,
            in: request.forceUnwrapped
        )

        dfRequest?.resume()
    }

    override func stopLoading() {
        dfRequest?.stop()
        dfRequest = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        fallbackSession?.invalidateAndCancel()
        fallbackSession = nil
    }
}

// MARK: DFRequestDelegate
extension DFURLProtocol: DFRequestDelegate {
    func dfRequestDidFinishLoading(_ request: DFRequest) {
        client?.urlProtocolDidFinishLoading(self)
    }
    func dfRequest(_ request: DFRequest, didLoad data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }
    func dfRequest(_ request: URLRequest, didFailWithError error: Error) {
        guard shouldFallback(for: error) else {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        startFallbackLoading()
    }
    func dfRequest(
        _ request: DFRequest, wasRedirectedTo urlRequest: URLRequest,
        redirectResponse: URLResponse
    ) {
        client?.urlProtocol(self, wasRedirectedTo: urlRequest, redirectResponse: redirectResponse)
    }
    func dfRequest(
        _ request: DFRequest, didReceive response: URLResponse,
        cacheStoragePolicy policy: URLCache.StoragePolicy
    ) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)
    }
}

private extension DFURLProtocol {
    func shouldFallback(for error: Error) -> Bool {
        guard request.url?.scheme == "https", fallbackTask == nil else { return false }

        let nsError = error as NSError
        if nsError.domain.localizedCaseInsensitiveContains("ssl") {
            return true
        }

        guard nsError.domain == NSURLErrorDomain else { return false }
        return [
            NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorClientCertificateRejected,
            NSURLErrorClientCertificateRequired
        ].contains(nsError.code)
    }

    func startFallbackLoading() {
        guard fallbackTask == nil,
              let request = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest
        else { return }

        dfRequest?.stop()
        dfRequest = nil

        DFURLProtocol.setProperty(
            true,
            forKey: Self.requestIdentifier,
            in: request
        )

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        fallbackSession = session
        fallbackTask = session.dataTask(with: request as URLRequest)
        fallbackTask?.resume()
    }
}

extension DFURLProtocol: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        fallbackTask = nil
        fallbackSession?.finishTasksAndInvalidate()
        fallbackSession = nil

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
