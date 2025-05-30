import Foundation
import ScreenCaptureKit
import CoreGraphics
import AVFoundation

@available(macOS 12.3, *)
@objc public class ScreenCaptureKitWrapper: NSObject, SCStreamOutput {
    private static var capturedData: Data?
    private static var semaphore: DispatchSemaphore?
    private static var currentStream: SCStream?

    // Capture first frame then stop
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        NSLog("SCK: Got frame")
        guard ScreenCaptureKitWrapper.capturedData == nil else { return }
        if let data = ScreenCaptureKitWrapper.rgbData(from: sampleBuffer) {
            NSLog("SCK: Converted to RGB: \(data.count) bytes")
            ScreenCaptureKitWrapper.capturedData = data
        }
        stream.stopCapture { _ in 
            ScreenCaptureKitWrapper.currentStream = nil
        }
        ScreenCaptureKitWrapper.semaphore?.signal()
    }

    @objc public static func captureMainDisplayRGB() -> NSData? {
        semaphore = DispatchSemaphore(value: 0)
        capturedData = nil
        let wrapper = ScreenCaptureKitWrapper()
        Task {
            do {
                NSLog("SCK: Starting capture task...")
                // Get shareable content
                let content = try await SCShareableContent.current
                NSLog("SCK: Got shareable content with \(content.displays.count) displays")
                
                // Find main display
                guard let mainDisplay = content.displays.first(where: { display in
                    display.displayID == CGMainDisplayID()
                }) else {
                    NSLog("SCK: Main display not found")
                    semaphore?.signal()
                    return
                }
                NSLog("SCK: Found main display: \(mainDisplay.width)x\(mainDisplay.height)")
                
                // Create filter for entire display
                let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
                
                // Configure stream
                let config = SCStreamConfiguration()
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                config.width = Int(mainDisplay.width)
                config.height = Int(mainDisplay.height)
                
                // Create and start stream
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                currentStream = stream
                let queue = DispatchQueue(label: "com.nutdart.screencapture")
                try stream.addStreamOutput(wrapper, type: .screen, sampleHandlerQueue: queue)
                try await stream.startCapture()
                NSLog("SCK: Stream started")
            } catch {
                NSLog("SCK: Error: \(error)")
                semaphore?.signal()
            }
        }
        _ = semaphore?.wait(timeout: .now() + 2) // wait up to 2s
        guard let data = capturedData else { return nil }
        return data as NSData
    }

    private static func rgbData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let buffer = sampleBuffer.imageBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let srcPtr = baseAddress.assumingMemoryBound(to: UInt8.self)
        var rgbData = Data(count: width * height * 3)
        rgbData.withUnsafeMutableBytes { dstPtr in
            var dst = dstPtr.bindMemory(to: UInt8.self).baseAddress!
            for y in 0..<height {
                let row = srcPtr + y * bytesPerRow
                for x in 0..<width {
                    let pixel = row + x * 4
                    dst[0] = pixel[2] // R
                    dst[1] = pixel[1] // G
                    dst[2] = pixel[0] // B
                    dst += 3
                }
            }
        }
        return rgbData
    }
}