#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "nutdart.h"

// Only available on macOS 12+ (ScreenCaptureKit)
// Returns NULL if ScreenCaptureKit is not available or permission denied.
CUBitmap* copyBitmapFullDisplay_SCK(void);

// Frees bitmap returned by the above function.
void destroyBitmap_SCK(CUBitmap* bmp);

// JPEG screenshot functions with resizing (macOS 12.3+)
// maxSmallDim/maxLargeDim: -1 means no limit
// quality: 0-100 (JPEG quality)
// outSize: pointer to receive the size of the returned JPEG data
// Returns malloc'd JPEG data that must be freed with freeJpegData_SCK
uint8_t* copyBitmapRegionJpeg_SCK(int64_t x, int64_t y, int64_t width, int64_t height,
                                  int32_t maxSmallDim, int32_t maxLargeDim, 
                                  int32_t quality, int64_t* outSize);
uint8_t* copyBitmapFullJpeg_SCK(int32_t maxSmallDim, int32_t maxLargeDim, 
                                int32_t quality, int64_t* outSize);
void freeJpegData_SCK(uint8_t* data);

#ifdef __cplusplus
}
#endif
