#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../screencapturekit_bridge.h"
#import "../nutdart.h"

#if __has_include(<ScreenCaptureKit/ScreenCaptureKit.h>)
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <AVFoundation/AVFoundation.h>

// For macOS 12.3+ with ScreenCaptureKit
API_AVAILABLE(macos(12.3))
@interface ScreenCaptureHelper : NSObject <SCStreamOutput>
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) NSData *capturedData;
@property (nonatomic, strong) SCStream *currentStream;
@end

@implementation ScreenCaptureHelper

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)outputType {
    if (self.capturedData != nil) return;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) return;
    
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Convert BGRA to RGB
    NSMutableData *rgbData = [NSMutableData dataWithLength:width * height * 3];
    uint8_t *dst = (uint8_t *)rgbData.mutableBytes;
    
    for (size_t y = 0; y < height; y++) {
        uint8_t *row = baseAddress + y * bytesPerRow;
        for (size_t x = 0; x < width; x++) {
            uint8_t *pixel = row + x * 4;
            *dst++ = pixel[2]; // R
            *dst++ = pixel[1]; // G
            *dst++ = pixel[0]; // B
        }
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    self.capturedData = rgbData;
    
    [stream stopCaptureWithCompletionHandler:^(NSError * _Nullable error) {
        self.currentStream = nil;
    }];
    
    dispatch_semaphore_signal(self.semaphore);
}

@end

CUBitmap* copyBitmapFullDisplay_SCK(void) {
    if (@available(macOS 12.3, *)) {
        __block CUBitmap* result = NULL;
        
        ScreenCaptureHelper *helper = [[ScreenCaptureHelper alloc] init];
        helper.semaphore = dispatch_semaphore_create(0);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable content, NSError * _Nullable error) {
                if (error || !content) {
                    dispatch_semaphore_signal(helper.semaphore);
                    return;
                }
                
                // Find main display
                SCDisplay *mainDisplay = nil;
                CGDirectDisplayID mainDisplayID = CGMainDisplayID();
                for (SCDisplay *display in content.displays) {
                    if (display.displayID == mainDisplayID) {
                        mainDisplay = display;
                        break;
                    }
                }
                
                if (!mainDisplay) {
                    dispatch_semaphore_signal(helper.semaphore);
                    return;
                }
                
                // Create filter and configuration
                SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:mainDisplay excludingWindows:@[]];
                SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
                config.pixelFormat = kCVPixelFormatType_32BGRA;
                config.minimumFrameInterval = CMTimeMake(1, 60);
                config.width = mainDisplay.width;
                config.height = mainDisplay.height;
                
                // Create stream
                SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:nil];
                helper.currentStream = stream;
                
                dispatch_queue_t queue = dispatch_queue_create("com.nutdart.screencapture", NULL);
                NSError *addError = nil;
                [stream addStreamOutput:helper type:SCStreamOutputTypeScreen sampleHandlerQueue:queue error:&addError];
                
                if (addError) {
                    dispatch_semaphore_signal(helper.semaphore);
                    return;
                }
                
                [stream startCaptureWithCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        dispatch_semaphore_signal(helper.semaphore);
                    }
                }];
            }];
        });
        
        // Wait for capture (max 2 seconds)
        dispatch_semaphore_wait(helper.semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
        
        if (helper.capturedData) {
            CUBitmap *bitmap = malloc(sizeof(CUBitmap));
            if (bitmap) {
                NSData *data = helper.capturedData;
                bitmap->width = CGDisplayPixelsWide(CGMainDisplayID());
                bitmap->height = CGDisplayPixelsHigh(CGMainDisplayID());
                bitmap->bytewidth = bitmap->width * 3;
                bitmap->data = malloc(data.length);
                if (bitmap->data) {
                    memcpy(bitmap->data, data.bytes, data.length);
                    result = bitmap;
                } else {
                    free(bitmap);
                }
            }
        }
        
        return result;
    }
    return NULL;
}

// Helper function to resize NSImage and convert to JPEG
static NSData* resizeImageAndConvertToJPEG(NSImage* image, int32_t maxSmallDim, int32_t maxLargeDim, int32_t quality) {
    if (!image) {
        return nil;
    }
    
    NSSize originalSize = image.size;
    NSSize newSize = originalSize;
    
    // Calculate new size based on constraints
    if (maxSmallDim > 0 || maxLargeDim > 0) {
        CGFloat width = originalSize.width;
        CGFloat height = originalSize.height;
        CGFloat smallDim = MIN(width, height);
        CGFloat largeDim = MAX(width, height);
        
        CGFloat scale = 1.0;
        
        // Apply small dimension constraint
        if (maxSmallDim > 0 && smallDim > maxSmallDim) {
            scale = MIN(scale, (CGFloat)maxSmallDim / smallDim);
        }
        
        // Apply large dimension constraint
        if (maxLargeDim > 0 && largeDim > maxLargeDim) {
            scale = MIN(scale, (CGFloat)maxLargeDim / largeDim);
        }
        
        newSize = NSMakeSize(width * scale, height * scale);

        NSLog(@"Resizing image from %@ to %@", NSStringFromSize(originalSize), NSStringFromSize(newSize));
    } else {
        NSLog(@"No resizing constraints provided, using original size: %@", NSStringFromSize(originalSize));
    }
    
    // Create bitmap directly at exact pixel size to avoid retina scaling
    NSBitmapImageRep* bitmapRep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:(NSInteger)newSize.width
                      pixelsHigh:(NSInteger)newSize.height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                   bitmapFormat:0
                    bytesPerRow:0
                   bitsPerPixel:0];
    
    // Save current graphics context
    [NSGraphicsContext saveGraphicsState];
    
    // Set the bitmap as the current context
    NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapRep];
    [NSGraphicsContext setCurrentContext:context];
    
    // Draw the image scaled to fit
    [image drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height)
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
    
    // Restore graphics context
    [NSGraphicsContext restoreGraphicsState];
    
    // Convert to JPEG
    NSDictionary* properties = @{
        NSImageCompressionFactor: @(quality / 100.0)
    };
    
    NSData* jpegData = [bitmapRep representationUsingType:NSBitmapImageFileTypeJPEG properties:properties];
    
    return jpegData;
}

uint8_t* copyBitmapFullJpeg_SCK(int maxSmallDim, int maxLargeDim, int quality, int64_t* outSize) {
    if (@available(macOS 12.3, *)) {
        NSLog(@"DEBUG: copyBitmapFullJpeg_SCK called with maxSmallDim=%d, maxLargeDim=%d, quality=%d", maxSmallDim, maxLargeDim, quality);
        
        CUBitmap *bitmap = copyBitmapFullDisplay_SCK();
        if (!bitmap) {
            NSLog(@"DEBUG: Failed to capture bitmap");
            if (outSize) *outSize = 0;
            return NULL;
        }
        
        NSLog(@"DEBUG: Got bitmap %lldx%lld", bitmap->width, bitmap->height);
        
        // Create NSImage from RGB data
        NSBitmapImageRep* imageRep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL
                          pixelsWide:bitmap->width
                          pixelsHigh:bitmap->height
                       bitsPerSample:8
                     samplesPerPixel:3
                            hasAlpha:NO
                            isPlanar:NO
                      colorSpaceName:NSCalibratedRGBColorSpace
                         bytesPerRow:bitmap->bytewidth
                        bitsPerPixel:24];
        
        // Copy the RGB data into the bitmap rep
        unsigned char* bitmapData = [imageRep bitmapData];
        if (!bitmapData) {
            cu_screen_free_capture(bitmap);
            if (outSize) *outSize = 0;
            return NULL;
        }
        
        memcpy(bitmapData, bitmap->data, bitmap->bytewidth * bitmap->height);
        
        NSImage* image = [[NSImage alloc] init];
        [image addRepresentation:imageRep];
        
        // Free the bitmap as we've copied the data
        cu_screen_free_capture(bitmap);
        
        // Resize and convert to JPEG
        NSData* jpegData = resizeImageAndConvertToJPEG(image, maxSmallDim, maxLargeDim, quality);
        
        if (!jpegData) {
            NSLog(@"DEBUG: Failed to convert to JPEG");
            if (outSize) *outSize = 0;
            return NULL;
        }
        
        NSLog(@"DEBUG: JPEG data size: %lu bytes", (unsigned long)jpegData.length);
        
        // Allocate and copy JPEG data
        uint8_t* result = (uint8_t*)malloc(jpegData.length);
        if (!result) {
            if (outSize) *outSize = 0;
            return NULL;
        }
        
        memcpy(result, jpegData.bytes, jpegData.length);
        if (outSize) *outSize = jpegData.length;
        
        return result;
    }
    if (outSize) *outSize = 0;
    return NULL;
}

uint8_t* copyBitmapRegionJpeg_SCK(int64_t x, int64_t y, int64_t width, int64_t height, 
                                  int maxSmallDim, int maxLargeDim, 
                                  int quality, int64_t* outSize) {
    // Not implemented yet
    return NULL;
}

void freeJpegData_SCK(uint8_t* jpegData) {
    if (jpegData) free(jpegData);
}

#else
// Stubs for older macOS versions
CUBitmap* copyBitmapFullDisplay_SCK(void) { return NULL; }
uint8_t* copyBitmapFullJpeg_SCK(int maxSmallDim, int maxLargeDim, int quality, int64_t* outSize) { return NULL; }
uint8_t* copyBitmapRegionJpeg_SCK(int x, int y, int width, int height, 
                                  int maxSmallDim, int maxLargeDim, 
                                  int quality, int64_t* outSize) { return NULL; }
void freeJpegData_SCK(uint8_t* jpegData) {}
#endif