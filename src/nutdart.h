#pragma once
#ifndef NUTDART_H
#define NUTDART_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Basic types matching libnut-core but simplified for FFI
typedef struct {
    int64_t x;
    int64_t y;
} CUPoint;

typedef struct {
    int64_t width;
    int64_t height;
} CUSize;

#ifdef __cplusplus
#include <cstdint>
#else
#include <stdint.h>
#endif

typedef struct {
    uint8_t r;
    uint8_t g;
    uint8_t b;
} CUColor;

// Mouse button constants (matching libnut-core)
#define CU_MOUSE_LEFT 1
#define CU_MOUSE_MIDDLE 2  // CENTER_BUTTON
#define CU_MOUSE_RIGHT 3

// Mouse functions
void cu_mouse_move(int64_t x, int64_t y);
void cu_mouse_click(int button);
void cu_mouse_double_click(int button);
void cu_mouse_drag(int64_t fromX, int64_t fromY, int64_t toX, int64_t toY, int button);
void cu_mouse_scroll(int deltaX, int deltaY);
CUPoint cu_mouse_get_position(void);
void cu_mouse_toggle(int down, int button); // down: 1=press, 0=release

// Keyboard functions (using libnut-core key names)
void cu_keyboard_key_tap(const char* key);
void cu_keyboard_key_tap_with_flags(const char* key, const char* flags); // flags: "alt", "control", "shift", "meta"
void cu_keyboard_type_string(const char* text);
void cu_keyboard_key_down(const char* key);
void cu_keyboard_key_up(const char* key);

// Screen functions
CUSize cu_screen_get_size(void);

// Screenshot functions (returns raw bitmap data)
typedef struct {
    uint8_t* data;
    int64_t width;
    int64_t height;
    int64_t bytewidth;
    uint8_t bitsPerPixel;
    uint8_t bytesPerPixel;
} CUBitmap;

CUBitmap* cu_screen_capture_region(int64_t x, int64_t y, int64_t width, int64_t height);
CUBitmap* cu_screen_capture_full(void);
void cu_screen_free_capture(CUBitmap* bitmap);

// JPEG screenshot functions with resizing
// maxSmallDim/maxLargeDim: -1 means no limit
// quality: 0-100 (JPEG quality)
// outSize: pointer to receive the size of the returned JPEG data
uint8_t* cu_screen_capture_region_jpeg(int64_t x, int64_t y, int64_t width, int64_t height, 
                                       int32_t maxSmallDim, int32_t maxLargeDim, 
                                       int32_t quality, int64_t* outSize);
uint8_t* cu_screen_capture_full_jpeg(int32_t maxSmallDim, int32_t maxLargeDim, 
                                     int32_t quality, int64_t* outSize);
void cu_screen_free_jpeg(uint8_t* data);

// Utility functions
void cu_sleep_ms(int milliseconds);

#ifdef __cplusplus
}
#endif

#endif // NUTDART_H