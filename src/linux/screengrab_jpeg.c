#include "../screengrab.h"
#include "../screen.h"
#include "../MMBitmap.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <jpeglib.h>
#include <jerror.h>

// Calculate new dimensions based on constraints
static void calculateResizedDimensions(int64_t originalWidth, int64_t originalHeight,
                                     int32_t maxSmallDim, int32_t maxLargeDim,
                                     int64_t* newWidth, int64_t* newHeight) {
    // Validate input parameters
    if (!newWidth || !newHeight || originalWidth <= 0 || originalHeight <= 0) {
        if (newWidth) *newWidth = 1;
        if (newHeight) *newHeight = 1;
        return;
    }
    
    *newWidth = originalWidth;
    *newHeight = originalHeight;
    
    // If no constraints, return original size
    if (maxSmallDim <= 0 && maxLargeDim <= 0) {
        return;
    }
    
    int64_t smallDim = (originalWidth < originalHeight) ? originalWidth : originalHeight;
    int64_t largeDim = (originalWidth > originalHeight) ? originalWidth : originalHeight;
    
    double scale = 1.0;
    
    // Apply small dimension constraint
    if (maxSmallDim > 0 && smallDim > maxSmallDim) {
        scale = (double)maxSmallDim / (double)smallDim;
    }
    
    // Apply large dimension constraint
    if (maxLargeDim > 0 && largeDim * scale > maxLargeDim) {
        scale = (double)maxLargeDim / (double)largeDim;
    }
    
    if (scale < 1.0) {
        *newWidth = (int64_t)(originalWidth * scale);
        *newHeight = (int64_t)(originalHeight * scale);
        
        // Ensure minimum size of 1x1
        if (*newWidth < 1) *newWidth = 1;
        if (*newHeight < 1) *newHeight = 1;
    }
}

// Simple bilinear resize function
static uint8_t* resizeBitmap(uint8_t* srcData, int64_t srcWidth, int64_t srcHeight, 
                           size_t srcBytewidth, uint8_t bytesPerPixel,
                           int64_t dstWidth, int64_t dstHeight, size_t* dstBytewidth) {
    if (!srcData || srcWidth <= 0 || srcHeight <= 0 || dstWidth <= 0 || dstHeight <= 0) {
        return NULL;
    }
    
    // Calculate destination bytewidth (aligned to 4 bytes)
    *dstBytewidth = ((dstWidth * bytesPerPixel + 3) / 4) * 4;
    
    uint8_t* dstData = (uint8_t*)malloc(*dstBytewidth * dstHeight);
    if (!dstData) {
        return NULL;
    }
    
    double xRatio = (double)srcWidth / (double)dstWidth;
    double yRatio = (double)srcHeight / (double)dstHeight;
    
    for (int64_t y = 0; y < dstHeight; y++) {
        for (int64_t x = 0; x < dstWidth; x++) {
            double srcX = x * xRatio;
            double srcY = y * yRatio;
            
            int64_t x1 = (int64_t)srcX;
            int64_t y1 = (int64_t)srcY;
            int64_t x2 = (x1 + 1 < srcWidth) ? x1 + 1 : x1;
            int64_t y2 = (y1 + 1 < srcHeight) ? y1 + 1 : y1;
            
            double xWeight = srcX - x1;
            double yWeight = srcY - y1;
            
            for (int c = 0; c < bytesPerPixel; c++) {
                uint8_t p1 = srcData[y1 * srcBytewidth + x1 * bytesPerPixel + c];
                uint8_t p2 = srcData[y1 * srcBytewidth + x2 * bytesPerPixel + c];
                uint8_t p3 = srcData[y2 * srcBytewidth + x1 * bytesPerPixel + c];
                uint8_t p4 = srcData[y2 * srcBytewidth + x2 * bytesPerPixel + c];
                
                double interpolated = p1 * (1 - xWeight) * (1 - yWeight) +
                                    p2 * xWeight * (1 - yWeight) +
                                    p3 * (1 - xWeight) * yWeight +
                                    p4 * xWeight * yWeight;
                
                dstData[y * *dstBytewidth + x * bytesPerPixel + c] = (uint8_t)interpolated;
            }
        }
    }
    
    return dstData;
}

// Convert bitmap pixel data to RGB (JPEG needs RGB)
// X11 can return different pixel formats (24-bit BGR, 32-bit BGRA, etc.)
static uint8_t* convertToRGB(uint8_t* srcData, int64_t width, int64_t height, 
                            size_t srcBytewidth, uint8_t bytesPerPixel, size_t* rgbBytewidth) {
    if (!srcData || width <= 0 || height <= 0) {
        return NULL;
    }
    
    *rgbBytewidth = width * 3;  // RGB is 3 bytes per pixel
    uint8_t* rgbData = (uint8_t*)malloc(*rgbBytewidth * height);
    if (!rgbData) {
        return NULL;
    }
    
    for (int64_t y = 0; y < height; y++) {
        for (int64_t x = 0; x < width; x++) {
            uint8_t* srcPixel = srcData + y * srcBytewidth + x * bytesPerPixel;
            uint8_t* dstPixel = rgbData + y * *rgbBytewidth + x * 3;
            
            if (bytesPerPixel == 4) {
                // 32-bit: Assume BGRA format
                dstPixel[0] = srcPixel[2]; // R = B from BGRA
                dstPixel[1] = srcPixel[1]; // G = G from BGRA  
                dstPixel[2] = srcPixel[0]; // B = R from BGRA
                // Alpha channel is ignored
            } else if (bytesPerPixel == 3) {
                // 24-bit: Assume BGR format
                dstPixel[0] = srcPixel[2]; // R = B from BGR
                dstPixel[1] = srcPixel[1]; // G = G from BGR
                dstPixel[2] = srcPixel[0]; // B = R from BGR
            } else {
                // Fallback: copy as-is and hope for the best
                dstPixel[0] = (bytesPerPixel > 0) ? srcPixel[0] : 0;
                dstPixel[1] = (bytesPerPixel > 1) ? srcPixel[1] : 0;
                dstPixel[2] = (bytesPerPixel > 2) ? srcPixel[2] : 0;
            }
        }
    }
    
    return rgbData;
}

// Memory destination manager for libjpeg
typedef struct {
    struct jpeg_destination_mgr pub;
    uint8_t** outbuffer;
    int64_t* outsize;
    uint8_t* buffer;
    size_t bufsize;
} mem_destination_mgr;

static void init_mem_destination(j_compress_ptr cinfo) {
    mem_destination_mgr* dest = (mem_destination_mgr*)cinfo->dest;
    dest->bufsize = 65536; // Start with 64KB
    dest->buffer = (uint8_t*)malloc(dest->bufsize);
    dest->pub.next_output_byte = dest->buffer;
    dest->pub.free_in_buffer = dest->bufsize;
}

static boolean empty_mem_output_buffer(j_compress_ptr cinfo) {
    mem_destination_mgr* dest = (mem_destination_mgr*)cinfo->dest;
    size_t oldsize = dest->bufsize;
    dest->bufsize *= 2;
    dest->buffer = (uint8_t*)realloc(dest->buffer, dest->bufsize);
    dest->pub.next_output_byte = dest->buffer + oldsize;
    dest->pub.free_in_buffer = dest->bufsize - oldsize;
    return TRUE;
}

static void term_mem_destination(j_compress_ptr cinfo) {
    mem_destination_mgr* dest = (mem_destination_mgr*)cinfo->dest;
    *dest->outsize = dest->bufsize - dest->pub.free_in_buffer;
    *dest->outbuffer = dest->buffer;
}

// Convert MMBitmap to JPEG using libjpeg
static uint8_t* convertBitmapToJpeg(MMBitmapRef bitmap, int32_t quality, 
                                   int64_t resizeWidth, int64_t resizeHeight,
                                   int64_t* outSize) {
    if (!bitmap || !outSize) {
        return NULL;
    }
    
    *outSize = 0;
    
    // Clamp quality to valid range
    int clampedQuality = quality;
    if (clampedQuality < 0) clampedQuality = 85;  // Default quality
    if (clampedQuality > 100) clampedQuality = 100;
    
    uint8_t* workingData = bitmap->imageBuffer;
    size_t workingBytewidth = bitmap->bytewidth;
    int64_t workingWidth = bitmap->width;
    int64_t workingHeight = bitmap->height;
    uint8_t* resizedData = NULL;
    
    // Resize if needed
    if (resizeWidth != bitmap->width || resizeHeight != bitmap->height) {
        size_t resizedBytewidth;
        resizedData = resizeBitmap(bitmap->imageBuffer, bitmap->width, bitmap->height,
                                 bitmap->bytewidth, bitmap->bytesPerPixel,
                                 resizeWidth, resizeHeight, &resizedBytewidth);
        if (!resizedData) {
            return NULL;
        }
        workingData = resizedData;
        workingBytewidth = resizedBytewidth;
        workingWidth = resizeWidth;
        workingHeight = resizeHeight;
    }
    
    // Convert to RGB format
    size_t rgbBytewidth;
    uint8_t* rgbData = convertToRGB(workingData, workingWidth, workingHeight,
                                   workingBytewidth, bitmap->bytesPerPixel, &rgbBytewidth);
    if (!rgbData) {
        if (resizedData) free(resizedData);
        return NULL;
    }
    
    // Setup JPEG compression
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    mem_destination_mgr dest_mgr;
    uint8_t* jpegData = NULL;
    
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    // Setup memory destination
    dest_mgr.pub.init_destination = init_mem_destination;
    dest_mgr.pub.empty_output_buffer = empty_mem_output_buffer;
    dest_mgr.pub.term_destination = term_mem_destination;
    dest_mgr.outbuffer = &jpegData;
    dest_mgr.outsize = outSize;
    cinfo.dest = (struct jpeg_destination_mgr*)&dest_mgr;
    
    // Set compression parameters
    cinfo.image_width = (JDIMENSION)workingWidth;
    cinfo.image_height = (JDIMENSION)workingHeight;
    cinfo.input_components = 3; // RGB
    cinfo.in_color_space = JCS_RGB;
    
    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, clampedQuality, TRUE);
    
    // Start compression
    jpeg_start_compress(&cinfo, TRUE);
    
    // Write scanlines
    JSAMPROW row_pointer[1];
    while (cinfo.next_scanline < cinfo.image_height) {
        row_pointer[0] = rgbData + cinfo.next_scanline * rgbBytewidth;
        jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }
    
    // Finish compression
    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    
    // Clean up
    free(rgbData);
    if (resizedData) free(resizedData);
    
    return jpegData;
}

// Linux implementation for region JPEG capture
uint8_t* copyBitmapRegionJpeg_LINUX(int64_t x, int64_t y, int64_t width, int64_t height, 
                                    int32_t maxSmallDim, int32_t maxLargeDim, 
                                    int32_t quality, int64_t* outSize) {
    if (outSize) *outSize = 0;
    
    // Capture the region as bitmap first
    MMBitmapRef bitmap = copyMMBitmapFromDisplayInRect(MMRectMake(x, y, width, height));
    if (!bitmap) {
        return NULL;
    }
    
    // Calculate resize dimensions
    int64_t newWidth, newHeight;
    calculateResizedDimensions(bitmap->width, bitmap->height, maxSmallDim, maxLargeDim, 
                              &newWidth, &newHeight);
    
    // Convert to JPEG
    uint8_t* result = convertBitmapToJpeg(bitmap, quality, newWidth, newHeight, outSize);
    
    // Clean up bitmap
    destroyMMBitmap(bitmap);
    
    return result;
}

// Linux implementation for full screen JPEG capture
uint8_t* copyBitmapFullJpeg_LINUX(int32_t maxSmallDim, int32_t maxLargeDim, 
                                  int32_t quality, int64_t* outSize) {
    if (outSize) *outSize = 0;
    
    // Get screen size
    MMSize screenSize = getMainDisplaySize();
    
    // Use region capture for full screen
    return copyBitmapRegionJpeg_LINUX(0, 0, screenSize.width, screenSize.height,
                                     maxSmallDim, maxLargeDim, quality, outSize);
}

// Free JPEG data allocated by Linux implementation
void freeJpegData_LINUX(uint8_t* data) {
    if (data) {
        free(data);
    }
}