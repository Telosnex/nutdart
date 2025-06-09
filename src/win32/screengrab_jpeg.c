#define COBJMACROS
 
#define WIN32_LEAN_AND_MEAN
 

#include "../screengrab.h"
#include "../screen.h"
#include "../MMBitmap.h"
#include <windows.h>
#include <wincodec.h>
#include <objbase.h>
#include <propvarutil.h>
#include <stdlib.h>
#include <math.h>
#include <windows.h>
#include <wincodec.h>
#include <ole2.h>
#include <objbase.h>
#include <initguid.h>  // Important for GUID definitions

// Define GUIDs if not available
#ifndef GUID_WICPixelFormat32bppBGRA
DEFINE_GUID(GUID_WICPixelFormat32bppBGRA, 0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x10);
#endif

#ifndef GUID_WICPixelFormat24bppBGR
DEFINE_GUID(GUID_WICPixelFormat24bppBGR, 0x6fddc324, 0x4e03, 0x4bfe, 0xb1, 0x85, 0x3d, 0x77, 0x76, 0x8d, 0xc9, 0x0c);
#endif

// COM initialization helper
static HRESULT initializeCOM() {
    static int initialized = 0;
    if (!initialized) {
        HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        if (SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE) {
            initialized = 1;
            return S_OK;
        }
        return hr;
    }
    return S_OK;
}

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

// Convert MMBitmap to JPEG using Windows Imaging Component
static uint8_t* convertBitmapToJpeg(MMBitmapRef bitmap, int32_t quality, 
                                   int64_t resizeWidth, int64_t resizeHeight,
                                   int64_t* outSize) {
    if (!bitmap || !outSize) {
        return NULL;
    }
    
    *outSize = 0;
    
    HRESULT hr = initializeCOM();
    if (FAILED(hr)) {
        return NULL;
    }
    
    IWICImagingFactory* factory = NULL;
    IWICBitmap* wicBitmap = NULL;
    IWICBitmapScaler* scaler = NULL;
    IWICStream* stream = NULL;
    IWICBitmapEncoder* encoder = NULL;
    IWICBitmapFrameEncode* frameEncode = NULL;
    IPropertyBag2* propertyBag = NULL;
    uint8_t* result = NULL;
    
    // Create WIC factory
    hr = CoCreateInstance(&CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER,
                         &IID_IWICImagingFactory, (void**)&factory);
    if (FAILED(hr)) {
        goto cleanup;
    }
    
    // Create WIC bitmap from our bitmap data
    // Note: MMBitmap uses BGRA format (32-bit) on Windows
    hr = IWICImagingFactory_CreateBitmapFromMemory(factory,
        (UINT)bitmap->width, (UINT)bitmap->height,
        &GUID_WICPixelFormat32bppBGRA,
        (UINT)bitmap->bytewidth,
        (UINT)(bitmap->bytewidth * bitmap->height),
        bitmap->imageBuffer,
        &wicBitmap);
    if (FAILED(hr)) {
        goto cleanup;
    }
    
    IWICBitmapSource* bitmapSource = (IWICBitmapSource*)wicBitmap;
    
    // If resizing is needed, create a scaler
    if (resizeWidth != bitmap->width || resizeHeight != bitmap->height) {
        hr = IWICImagingFactory_CreateBitmapScaler(factory, &scaler);
        if (FAILED(hr)) {
            goto cleanup;
        }
        
        hr = IWICBitmapScaler_Initialize(scaler, bitmapSource,
            (UINT)resizeWidth, (UINT)resizeHeight,
            WICBitmapInterpolationModeLinear);
        if (FAILED(hr)) {
            goto cleanup;
        }
        
        bitmapSource = (IWICBitmapSource*)scaler;
    }
    
    // Create memory stream for in-memory JPEG encoding
    IStream* memoryStream = NULL;
    hr = CreateStreamOnHGlobal(NULL, TRUE, &memoryStream);
    if (FAILED(hr)) {
        goto cleanup;
    }

    hr = IWICImagingFactory_CreateStream(factory, &stream);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    hr = IWICStream_InitializeFromIStream(stream, memoryStream);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }
    // Initialize encoder with stream
    hr = IWICBitmapEncoder_Initialize(encoder, (IStream*)stream, WICBitmapEncoderNoCache);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Create frame encoder
    hr = IWICBitmapEncoder_CreateNewFrame(encoder, &frameEncode, &propertyBag);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Set JPEG quality (clamp to valid range)
    if (propertyBag) {
        int clampedQuality = quality;
        if (clampedQuality < 0) clampedQuality = 85;  // Default quality
        if (clampedQuality > 100) clampedQuality = 100;
        
        PROPBAG2 option = { 0 };
        option.pstrName = L"ImageQuality";
        VARIANT varValue;
        VariantInit(&varValue);
        varValue.vt = VT_R4;
        varValue.fltVal = (float)clampedQuality / 100.0f;
        
        IPropertyBag2_Write(propertyBag, 1, &option, &varValue);
        VariantClear(&varValue);
    }
    // Initialize frame encoder
    hr = IWICBitmapFrameEncode_Initialize(frameEncode, propertyBag);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Set frame size
    hr = IWICBitmapFrameEncode_SetSize(frameEncode, (UINT)resizeWidth, (UINT)resizeHeight);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Set pixel format (let WIC convert if needed)
    WICPixelFormatGUID pixelFormat = GUID_WICPixelFormat24bppBGR;
    hr = IWICBitmapFrameEncode_SetPixelFormat(frameEncode, &pixelFormat);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Write bitmap source to frame
    hr = IWICBitmapFrameEncode_WriteSource(frameEncode, bitmapSource, NULL);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Commit frame and encoder
    hr = IWICBitmapFrameEncode_Commit(frameEncode);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    hr = IWICBitmapEncoder_Commit(encoder);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Get the data from memory stream
    HGLOBAL hGlobal = NULL;
    hr = GetHGlobalFromStream(memoryStream, &hGlobal);
    if (FAILED(hr)) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    SIZE_T dataSize = GlobalSize(hGlobal);
    void* data = GlobalLock(hGlobal);
    if (!data) {
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    // Copy data to our result buffer
    *outSize = (int64_t)dataSize;
    result = (uint8_t*)malloc(dataSize);
    if (!result) {
        *outSize = 0;
        GlobalUnlock(hGlobal);
        if (memoryStream) IStream_Release(memoryStream);
        goto cleanup;
    }

    memcpy(result, data, dataSize);
    GlobalUnlock(hGlobal);

    // Release memory stream
    if (memoryStream) {
        IStream_Release(memoryStream);
        memoryStream = NULL;
    }
    
cleanup:
    if (propertyBag) IPropertyBag2_Release(propertyBag);
    if (frameEncode) IWICBitmapFrameEncode_Release(frameEncode);
    if (encoder) IWICBitmapEncoder_Release(encoder);
    if (stream) IWICStream_Release(stream);
    if (scaler) IWICBitmapScaler_Release(scaler);
    if (wicBitmap) IWICBitmap_Release(wicBitmap);
    if (factory) IWICImagingFactory_Release(factory);

    
    return result;
}

// Windows implementation for region JPEG capture
uint8_t* copyBitmapRegionJpeg_WIN32(int64_t x, int64_t y, int64_t width, int64_t height, 
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

// Windows implementation for full screen JPEG capture
uint8_t* copyBitmapFullJpeg_WIN32(int32_t maxSmallDim, int32_t maxLargeDim, 
                                  int32_t quality, int64_t* outSize) {
    if (outSize) *outSize = 0;
         MessageBoxA(NULL, "copyBitmapFullJpeg_WIN32 CALLED!", "NUTDART", MB_OK); 

    // Get screen size
    MMSize screenSize = getMainDisplaySize();
    
    // Use region capture for full screen
    return copyBitmapRegionJpeg_WIN32(0, 0, screenSize.width, screenSize.height,
                                     maxSmallDim, maxLargeDim, quality, outSize);
}

// Free JPEG data allocated by Windows implementation
void freeJpegData_WIN32(uint8_t* data) {
    if (data) {
        free(data);
    }
}