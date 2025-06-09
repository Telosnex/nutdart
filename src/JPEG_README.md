# JPEG Screen Capture Implementation

This document describes the cross-platform JPEG screen capture functionality added to nutdart.

## Overview

The JPEG screen capture feature allows capturing screenshots directly as JPEG data with optional resizing and quality control. This is more efficient than capturing raw bitmap data and converting it separately.

## API Functions

### `cu_screen_capture_full_jpeg`
```c
uint8_t* cu_screen_capture_full_jpeg(int32_t maxSmallDim, int32_t maxLargeDim, 
                                     int32_t quality, int64_t* outSize);
```
Captures the entire screen as JPEG data.

**Parameters:**
- `maxSmallDim`: Maximum size for the smaller dimension (-1 for no limit)
- `maxLargeDim`: Maximum size for the larger dimension (-1 for no limit)  
- `quality`: JPEG quality (0-100, clamped automatically)
- `outSize`: Pointer to receive the size of the returned JPEG data

**Returns:** Pointer to JPEG data (must be freed with `cu_screen_free_jpeg`) or NULL on error.

### `cu_screen_capture_region_jpeg`
```c
uint8_t* cu_screen_capture_region_jpeg(int64_t x, int64_t y, int64_t width, int64_t height, 
                                       int32_t maxSmallDim, int32_t maxLargeDim, 
                                       int32_t quality, int64_t* outSize);
```
Captures a specific screen region as JPEG data.

**Parameters:**
- `x`, `y`: Top-left corner of the region to capture
- `width`, `height`: Size of the region to capture
- `maxSmallDim`: Maximum size for the smaller dimension (-1 for no limit)
- `maxLargeDim`: Maximum size for the larger dimension (-1 for no limit)
- `quality`: JPEG quality (0-100, clamped automatically)
- `outSize`: Pointer to receive the size of the returned JPEG data

**Returns:** Pointer to JPEG data (must be freed with `cu_screen_free_jpeg`) or NULL on error.

### `cu_screen_free_jpeg`
```c
void cu_screen_free_jpeg(uint8_t* data);
```
Frees JPEG data returned by the capture functions.

**Parameters:**
- `data`: Pointer to JPEG data to free

## Resizing Logic

The resizing algorithm works as follows:

1. If both `maxSmallDim` and `maxLargeDim` are -1 or 0, no resizing is performed
2. The smaller and larger dimensions of the original image are identified
3. If `maxSmallDim` > 0 and the small dimension exceeds it, scale down to fit
4. If `maxLargeDim` > 0 and the large dimension (after small dim scaling) exceeds it, scale down further
5. The final dimensions maintain the original aspect ratio
6. Minimum size is enforced as 1x1 pixels

**Example:**
- Original: 1920x1080 (small=1080, large=1920)
- maxSmallDim=800, maxLargeDim=1200
- Scale for small dim: 800/1080 = 0.741
- After scaling: 1422x800 (large dim now 1422 > 1200)
- Scale for large dim: 1200/1422 = 0.844
- Final result: 1200x675

## Platform Implementations

### macOS
- Uses **ScreenCaptureKit** (macOS 12.3+) for hardware-accelerated capture
- Provides native JPEG encoding with resizing
- Falls back to older APIs if ScreenCaptureKit unavailable

### Windows
- Uses **Windows Imaging Component (WIC)** for JPEG encoding
- Captures via GDI and converts BGRA to JPEG
- Handles COM initialization and resource management
- Uses temporary files for reliable WIC stream handling

### Linux
- Uses **libjpeg/libjpeg-turbo** for JPEG encoding
- Captures via X11 and handles both 24-bit BGR and 32-bit BGRA formats
- Implements custom bilinear resizing algorithm
- Converts pixel formats appropriately for JPEG encoding

## Dependencies

### Windows
- `ole32.lib` - COM support
- `windowscodecs.lib` - Windows Imaging Component

### Linux
- `libjpeg-dev` or `libjpeg-turbo-dev` - JPEG encoding library
- X11 libraries (already required)

### macOS
- `ScreenCaptureKit.framework` (already included)
- `AVFoundation.framework` (already included)

## Build Configuration

The CMakeLists.txt automatically detects the platform and includes the appropriate implementation:

```cmake
# Windows
set(PLATFORM_LIBS user32 gdi32 ole32 windowscodecs)

# Linux  
pkg_check_modules(JPEG REQUIRED libjpeg)
set(PLATFORM_LIBS ${X11_LIBRARIES} ${XTST_LIBRARIES} ${XINERAMA_LIBRARIES} ${JPEG_LIBRARIES})

# macOS (no additional libs needed)
```

## Usage Example

```c
#include "nutdart.h"

// Capture full screen with max 800px small dimension, quality 85
int64_t size = 0;
uint8_t* jpegData = cu_screen_capture_full_jpeg(800, -1, 85, &size);

if (jpegData && size > 0) {
    // Save to file
    FILE* f = fopen("screenshot.jpg", "wb");
    fwrite(jpegData, 1, size, f);
    fclose(f);
    
    // Free the data
    cu_screen_free_jpeg(jpegData);
}

// Capture region with resizing
jpegData = cu_screen_capture_region_jpeg(100, 100, 400, 300, 400, 600, 90, &size);
if (jpegData) {
    // Process JPEG data...
    cu_screen_free_jpeg(jpegData);
}
```

## Error Handling

Functions return NULL on error and set `*outSize` to 0. Common error conditions:

- Invalid screen coordinates or dimensions
- Insufficient memory
- Platform-specific capture failures (permissions, display issues)
- JPEG encoding failures