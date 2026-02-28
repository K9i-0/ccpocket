import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import ImageIO
import CoreImage
import AppKit

// MARK: - CLI Arguments

struct Config {
    var windowId: CGWindowID = 0
    var fps: Int = 30
    var quality: Double = 0.7
    var scale: Double = 1.0

    static func parse() -> Config {
        var config = Config()
        let args = CommandLine.arguments
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--window-id":
                i += 1; config.windowId = CGWindowID(UInt32(args[i]) ?? 0)
            case "--fps":
                i += 1; config.fps = Int(args[i]) ?? 30
            case "--quality":
                i += 1; config.quality = Double(args[i]) ?? 0.7
            case "--scale":
                i += 1; config.scale = Double(args[i]) ?? 1.0
            case "--help", "-h":
                printUsage(); exit(0)
            default:
                break
            }
            i += 1
        }
        return config
    }

    static func printUsage() {
        log("Usage: screencapturekit-daemon [options]")
        log("  --window-id <ID>    CGWindowID of the simulator window (required)")
        log("  --fps <N>           Target frames per second (default: 30)")
        log("  --quality <0-1>     JPEG quality (default: 0.7)")
        log("  --scale <0-1>       Scale factor (default: 1.0)")
    }
}

// MARK: - Logging (stderr only, stdout is for frame data)

func log(_ message: String) {
    FileHandle.standardError.write(Data("[daemon] \(message)\n".utf8))
}

// MARK: - JPEG Encoder

class JpegEncoder {
    let quality: Double
    private let ciContext: CIContext

    init(quality: Double) {
        self.quality = quality
        // Use Metal-accelerated CIContext for fast encoding
        self.ciContext = CIContext(options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
        ])
    }

    func encode(pixelBuffer: CVPixelBuffer) -> Data? {
        // Use CGImage + ImageIO for faster JPEG encoding than CIContext.jpegRepresentation
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Create CGImage directly from pixel buffer (BGRA → CGImage)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        // Encode to JPEG using ImageIO
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}

// MARK: - Frame Output (length-prefixed binary to stdout)

class FrameWriter {
    private let fd: Int32 = STDOUT_FILENO
    private var frameCount: UInt64 = 0
    private let startTime = Date()

    init() {
        // Disable stdout buffering for real-time streaming
        setbuf(stdout, nil)
    }

    // Frame types
    static let typeFrame: UInt8 = 0  // JPEG frame (screen changed)
    static let typeIdle: UInt8 = 1   // No change (no payload)

    func write(jpegData: Data) {
        // Protocol: [4 bytes BE uint32 = length][1 byte type][JPEG data]
        let payloadLen = 1 + jpegData.count  // type byte + JPEG
        var length = UInt32(payloadLen).bigEndian
        let headerData = Data(bytes: &length, count: 4)
        let typeByte = Data([FrameWriter.typeFrame])

        // Use low-level write to avoid buffering
        headerData.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, ptr.count)
        }
        typeByte.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, ptr.count)
        }
        jpegData.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, ptr.count)
        }

        frameCount += 1

        // Log stats every 5 seconds worth of frames
        if frameCount % 150 == 0 {
            let elapsed = Date().timeIntervalSince(startTime)
            let fps = Double(frameCount) / elapsed
            log("frames=\(frameCount) fps=\(String(format: "%.1f", fps)) size=\(jpegData.count / 1024)KB")
        }
    }

    func writeIdle() {
        // Protocol: [4 bytes BE uint32 = 1][1 byte type=idle]
        var length = UInt32(1).bigEndian
        let headerData = Data(bytes: &length, count: 4)
        let typeByte = Data([FrameWriter.typeIdle])

        headerData.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, ptr.count)
        }
        typeByte.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, ptr.count)
        }
    }
}

// MARK: - Stream Output Handler

class StreamOutputHandler: NSObject, SCStreamOutput {
    let encoder: JpegEncoder
    let writer: FrameWriter

    init(encoder: JpegEncoder, writer: FrameWriter) {
        self.encoder = encoder
        self.writer = writer
    }

    private var receivedFrames: UInt64 = 0
    private var completeFrames: UInt64 = 0
    private var lastFrame: Data? = nil

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard sampleBuffer.isValid else { return }

        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let statusRaw = attachments[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRaw) else {
            return
        }

        receivedFrames += 1
        if receivedFrames <= 3 {
            log("Frame #\(receivedFrames): status=\(statusRaw)")
        }

        // For idle frames (no change), notify Node.js but don't resend JPEG
        if status == .idle {
            writer.writeIdle()
            return
        }

        guard status == .complete else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        guard let jpegData = encoder.encode(pixelBuffer: pixelBuffer) else {
            return
        }

        completeFrames += 1
        lastFrame = jpegData
        writer.write(jpegData: jpegData)
    }
}

// MARK: - Stream Delegate

class StreamDelegate: NSObject, SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log("Stream stopped with error: \(error.localizedDescription)")
        exit(1)
    }
}

// MARK: - Main

@MainActor
func run() async {
    let config = Config.parse()

    guard config.windowId != 0 else {
        log("Error: --window-id is required")
        Config.printUsage()
        exit(1)
    }

    log("Starting ScreenCaptureKit daemon")
    log("  window-id: \(config.windowId)")
    log("  fps: \(config.fps)")
    log("  quality: \(config.quality)")
    log("  scale: \(config.scale)")

    // Find the window
    let content: SCShareableContent
    do {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch {
        log("Error: Failed to get shareable content: \(error.localizedDescription)")
        log("Make sure Screen Recording permission is granted in System Settings > Privacy & Security")
        exit(1)
    }

    guard let window = content.windows.first(where: { $0.windowID == config.windowId }) else {
        log("Error: Window ID \(config.windowId) not found")
        log("Available windows:")
        for w in content.windows where w.isOnScreen {
            log("  [\(w.windowID)] \(w.owningApplication?.applicationName ?? "?") - \(w.title ?? "(no title)") (\(Int(w.frame.width))x\(Int(w.frame.height)))")
        }
        exit(1)
    }

    log("Found window: \(window.owningApplication?.applicationName ?? "?") - \(window.title ?? "(no title)")")
    log("  Frame: \(Int(window.frame.width))x\(Int(window.frame.height))")

    // Configure stream
    let streamConfig = SCStreamConfiguration()

    let captureWidth = Int(window.frame.width * config.scale)
    let captureHeight = Int(window.frame.height * config.scale)
    streamConfig.width = captureWidth
    streamConfig.height = captureHeight

    streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
    streamConfig.showsCursor = false
    streamConfig.capturesAudio = false
    streamConfig.pixelFormat = kCVPixelFormatType_32BGRA

    log("Capture resolution: \(captureWidth)x\(captureHeight)")

    // Create filter for window
    let filter = SCContentFilter(desktopIndependentWindow: window)

    // Create stream
    let delegate = StreamDelegate()
    let stream: SCStream
    do {
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: delegate)
    }

    // Setup output handler
    let encoder = JpegEncoder(quality: config.quality)
    let writer = FrameWriter()
    let outputHandler = StreamOutputHandler(encoder: encoder, writer: writer)

    do {
        try stream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
    } catch {
        log("Error: Failed to add stream output: \(error.localizedDescription)")
        exit(1)
    }

    // Start streaming
    do {
        try await stream.startCapture()
    } catch {
        log("Error: Failed to start capture: \(error.localizedDescription)")
        exit(1)
    }

    log("Streaming started at \(config.fps)fps")

    // Handle SIGINT/SIGTERM for graceful shutdown
    func setupSignalHandler(_ sig: Int32) {
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        signal(sig, SIG_IGN)
        source.setEventHandler {
            Task { @MainActor in
                log("Shutting down...")
                try? await stream.stopCapture()
                exit(0)
            }
        }
        source.resume()
        // Prevent source from being deallocated
        withExtendedLifetime(source) {}
    }
    setupSignalHandler(SIGINT)
    setupSignalHandler(SIGTERM)

    // Keep this async function alive forever so the stream stays active.
    // NSApplication.run() manages the main RunLoop, but we must not return
    // from this async context or the stream/delegate/output objects go out of scope.
    await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in
        // Never resumes — process exits via signal handler
    }
}

// MARK: - App Delegate (needed for CGS initialization)

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await run()
        }
    }
}

// Entry point - NSApplication is required for ScreenCaptureKit
// to properly initialize the CoreGraphics connection
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
