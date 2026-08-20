import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ProbeImageMetadata {
    let width: Int
    let height: Int
    let typeIdentifier: String
}

enum ProbeImageValidator {
    static let maximumBytes = 50 * 1_024 * 1_024

    static func inspect(data: Data, mimeType: String) throws -> ProbeImageMetadata {
        try require(data.count <= maximumBytes, "Image exceeded the 50 MB limit")
        try require(mimeType.lowercased().hasPrefix("image/"), "Response MIME type is not an image")

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ProbeFailure("ImageIO could not decode the response")
        }

        let allowedTypes = [UTType.jpeg, .png, .heic, .webP].map(\.identifier)
        try require(allowedTypes.contains(type), "Decoded image format is not supported")
        try require(width > 0 && height > 0, "Decoded image has invalid dimensions")

        return ProbeImageMetadata(width: width, height: height, typeIdentifier: type)
    }
}

struct StreamingSizeLimiter {
    let limit: Int
    private(set) var byteCount = 0

    mutating func receive(_ data: Data) throws {
        let (newCount, overflowed) = byteCount.addingReportingOverflow(data.count)
        try require(!overflowed && newCount <= limit, "Download exceeded its byte limit while streaming")
        byteCount = newCount
    }
}

final class ProbeURLProtocol: URLProtocol {
    static var payload = Data()
    static var chunkSize = 1

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "zikora-probe"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "image/png"]
              ) else {
            client?.urlProtocol(self, didFailWithError: ProbeFailure("Could not create fixture response"))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        var offset = 0
        while offset < Self.payload.count {
            let end = min(offset + max(Self.chunkSize, 1), Self.payload.count)
            client?.urlProtocol(self, didLoad: Self.payload.subdata(in: offset..<end))
            offset = end
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class CappedDownloadDelegate: NSObject, URLSessionDataDelegate {
    private let limit: Int
    private var receivedData = Data()
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: URLSession?
    private var completed = false

    init(limit: Int) {
        self.limit = limit
    }

    func download(_ request: URLRequest, configuration: URLSessionConfiguration) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            self.session = session
            session.dataTask(with: request).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard !completed else { return }
        let (newCount, overflowed) = receivedData.count.addingReportingOverflow(data.count)
        guard !overflowed, newCount <= limit else {
            completed = true
            dataTask.cancel()
            continuation?.resume(throwing: ProbeFailure("URLSession stream exceeded its byte limit"))
            continuation = nil
            session.invalidateAndCancel()
            return
        }
        receivedData.append(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard !completed else { return }
        completed = true
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: receivedData)
        }
        continuation = nil
        session.finishTasksAndInvalidate()
    }
}

enum ImageAndNetworkProbe {
    static func run() async throws {
        let pngData = try makePNG()
        let metadata = try ProbeImageValidator.inspect(data: pngData, mimeType: "image/png")
        try require(metadata.width == 2 && metadata.height == 2, "Unexpected decoded PNG dimensions")
        try require(metadata.typeIdentifier == UTType.png.identifier, "Unexpected decoded image format")

        do {
            _ = try ProbeImageValidator.inspect(data: pngData, mimeType: "text/html")
            throw ProbeFailure("A non-image MIME type was accepted")
        } catch let error as ProbeFailure where error.description == "Response MIME type is not an image" {
            // Expected.
        }

        var limiter = StreamingSizeLimiter(limit: 8)
        try limiter.receive(Data(repeating: 0, count: 4))
        do {
            try limiter.receive(Data(repeating: 0, count: 5))
            throw ProbeFailure("Streaming limiter accepted more bytes than its cap")
        } catch let error as ProbeFailure where error.description.contains("exceeded") {
            // Expected.
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProbeURLProtocol.self]
        ProbeURLProtocol.payload = Data(repeating: 1, count: 12)
        ProbeURLProtocol.chunkSize = 3
        let request = URLRequest(url: try requireProbeURL())

        do {
            _ = try await CappedDownloadDelegate(limit: 8).download(request, configuration: configuration)
            throw ProbeFailure("URLSession streaming adapter accepted more bytes than its cap")
        } catch let error as ProbeFailure where error.description.contains("exceeded") {
            // Expected.
        }

        ProbeURLProtocol.payload = pngData
        ProbeURLProtocol.chunkSize = 5
        let downloaded = try await CappedDownloadDelegate(limit: pngData.count).download(
            request,
            configuration: configuration
        )
        try require(downloaded == pngData, "URLSession fixture changed the downloaded bytes")

        reportPass("ImageIO validation and streaming byte-limit enforcement")
    }

    private static func makePNG() throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ProbeFailure("Could not create image context")
        }
        context.setFillColor(CGColor(red: 0, green: 0.48, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        guard let image = context.makeImage() else {
            throw ProbeFailure("Could not create probe image")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ProbeFailure("Could not create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        try require(CGImageDestinationFinalize(destination), "Could not encode probe PNG")
        return data as Data
    }

    private static func requireProbeURL() throws -> URL {
        guard let url = URL(string: "zikora-probe://fixture/image") else {
            throw ProbeFailure("Could not construct fixture URL")
        }
        return url
    }
}

