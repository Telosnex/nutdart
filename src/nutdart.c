#include "nutdart.h"
#include "mouse.h"
#include "keypress.h"
#include "screen.h"
#include "screengrab.h"
#include "microsleep.h"
#include "keycode.h"
#include "MMBitmap.h"
#include <stdlib.h>
#include <string.h>

// Helper function to convert key string to MMKeyCode
MMKeyCode stringToKeyCode(const char* key) {
    if (!key) return K_NOT_A_KEY;
    
    // Single character keys
    if (strlen(key) == 1) {
        return keyCodeForChar(key[0]);
    }
    
    // Named keys (from main.cc key_names array)
    if (strcmp(key, "backspace") == 0) return K_BACKSPACE;
    if (strcmp(key, "delete") == 0) return K_DELETE;
    if (strcmp(key, "return") == 0) return K_RETURN;
    if (strcmp(key, "tab") == 0) return K_TAB;
    if (strcmp(key, "escape") == 0) return K_ESCAPE;
    
    if (strcmp(key, "up") == 0) return K_UP;
    if (strcmp(key, "down") == 0) return K_DOWN;
    if (strcmp(key, "right") == 0) return K_RIGHT;
    if (strcmp(key, "left") == 0) return K_LEFT;
    
    if (strcmp(key, "home") == 0) return K_HOME;
    if (strcmp(key, "end") == 0) return K_END;
    if (strcmp(key, "pageup") == 0) return K_PAGEUP;
    if (strcmp(key, "pagedown") == 0) return K_PAGEDOWN;
    
    // Function keys
    if (strcmp(key, "f1") == 0) return K_F1;
    if (strcmp(key, "f2") == 0) return K_F2;
    if (strcmp(key, "f3") == 0) return K_F3;
    if (strcmp(key, "f4") == 0) return K_F4;
    if (strcmp(key, "f5") == 0) return K_F5;
    if (strcmp(key, "f6") == 0) return K_F6;
    if (strcmp(key, "f7") == 0) return K_F7;
    if (strcmp(key, "f8") == 0) return K_F8;
    if (strcmp(key, "f9") == 0) return K_F9;
    if (strcmp(key, "f10") == 0) return K_F10;
    if (strcmp(key, "f11") == 0) return K_F11;
    if (strcmp(key, "f12") == 0) return K_F12;
    
    // Modifier keys
    if (strcmp(key, "meta") == 0) return K_META;
    if (strcmp(key, "cmd") == 0) return K_CMD;
    if (strcmp(key, "win") == 0) return K_WIN;
    if (strcmp(key, "alt") == 0) return K_ALT;
    if (strcmp(key, "control") == 0) return K_CONTROL;
    if (strcmp(key, "shift") == 0) return K_SHIFT;
    if (strcmp(key, "space") == 0) return K_SPACE;
    
    // Special keys
    if (strcmp(key, "enter") == 0) return K_ENTER;
    if (strcmp(key, "clear") == 0) return K_CLEAR;
    
    return K_NOT_A_KEY;
}

// Helper function to parse flags string
MMKeyFlags parseKeyFlags(const char* flags) {
    if (!flags) return MOD_NONE;
    
    MMKeyFlags result = MOD_NONE;
    char* flags_copy = strdup(flags);
    char* token = strtok(flags_copy, ",");
    
    while (token != NULL) {
        // Trim whitespace
        while (*token == ' ') token++;
        
        if (strcmp(token, "alt") == 0) {
            result |= MOD_ALT;
        } else if (strcmp(token, "control") == 0) {
            result |= MOD_CONTROL;
        } else if (strcmp(token, "shift") == 0) {
            result |= MOD_SHIFT;
        } else if (strcmp(token, "meta") == 0 || strcmp(token, "cmd") == 0 || strcmp(token, "win") == 0) {
            result |= MOD_META;
        } else if (strcmp(token, "fn") == 0) {
            result |= MOD_FN;
        }
        
        token = strtok(NULL, ",");
    }
    
    free(flags_copy);
    return result;
}

// Mouse functions
void cu_mouse_move(int64_t x, int64_t y) {
    MMPoint point = MMPointMake(x, y);
    moveMouse(point);
}

void cu_mouse_click(int button) {
    MMMouseButton btn;
    switch (button) {
        case CU_MOUSE_LEFT:
            btn = LEFT_BUTTON;
            break;
        case CU_MOUSE_MIDDLE:
            btn = CENTER_BUTTON;
            break;
        case CU_MOUSE_RIGHT:
            btn = RIGHT_BUTTON;
            break;
        default:
            btn = LEFT_BUTTON;
            break;
    }
    clickMouse(btn);
}

void cu_mouse_double_click(int button) {
    MMMouseButton btn;
    switch (button) {
        case CU_MOUSE_LEFT:
            btn = LEFT_BUTTON;
            break;
        case CU_MOUSE_MIDDLE:
            btn = CENTER_BUTTON;
            break;
        case CU_MOUSE_RIGHT:
            btn = RIGHT_BUTTON;
            break;
        default:
            btn = LEFT_BUTTON;
            break;
    }
    doubleClick(btn);
}

void cu_mouse_drag(int64_t fromX, int64_t fromY, int64_t toX, int64_t toY, int button) {
    MMMouseButton btn;
    switch (button) {
        case CU_MOUSE_LEFT:
            btn = LEFT_BUTTON;
            break;
        case CU_MOUSE_MIDDLE:
            btn = CENTER_BUTTON;
            break;
        case CU_MOUSE_RIGHT:
            btn = RIGHT_BUTTON;
            break;
        default:
            btn = LEFT_BUTTON;
            break;
    }
    
    // Move to start position and start drag
    MMPoint fromPoint = MMPointMake(fromX, fromY);
    moveMouse(fromPoint);
    toggleMouse(true, btn);  // Press down
    
    // Drag to end position
    MMPoint toPoint = MMPointMake(toX, toY);
    dragMouse(toPoint, btn);
    
    // Release mouse
    toggleMouse(false, btn);
}

void cu_mouse_scroll(int deltaX, int deltaY) {
    scrollMouse(deltaX, deltaY);
}

CUPoint cu_mouse_get_position(void) {
    MMPoint pos = getMousePos();
    CUPoint result = {pos.x, pos.y};
    return result;
}

void cu_mouse_toggle(int down, int button) {
    MMMouseButton btn;
    switch (button) {
        case CU_MOUSE_LEFT:
            btn = LEFT_BUTTON;
            break;
        case CU_MOUSE_MIDDLE:
            btn = CENTER_BUTTON;
            break;
        case CU_MOUSE_RIGHT:
            btn = RIGHT_BUTTON;
            break;
        default:
            btn = LEFT_BUTTON;
            break;
    }
    toggleMouse(down != 0, btn);
}

// Keyboard functions
void cu_keyboard_key_tap(const char* key) {
    MMKeyCode keyCode = stringToKeyCode(key);
    if (keyCode != K_NOT_A_KEY) {
        tapKeyCode(keyCode, MOD_NONE);
    }
}

void cu_keyboard_key_tap_with_flags(const char* key, const char* flags) {
    MMKeyCode keyCode = stringToKeyCode(key);
    MMKeyFlags keyFlags = parseKeyFlags(flags);
    
    if (keyCode != K_NOT_A_KEY) {
        tapKeyCode(keyCode, keyFlags);
    }
}

void cu_keyboard_type_string(const char* text) {
    typeString(text);
}

void cu_keyboard_key_down(const char* key) {
    MMKeyCode keyCode = stringToKeyCode(key);
    if (keyCode != K_NOT_A_KEY) {
        toggleKeyCode(keyCode, true, MOD_NONE);
    }
}

void cu_keyboard_key_up(const char* key) {
    MMKeyCode keyCode = stringToKeyCode(key);
    if (keyCode != K_NOT_A_KEY) {
        toggleKeyCode(keyCode, false, MOD_NONE);
    }
}

// Screen functions
CUSize cu_screen_get_size(void) {
    MMSize size = getMainDisplaySize();
    CUSize result = {size.width, size.height};
    return result;
}

// Screenshot functions
CUBitmap* cu_screen_capture_region(int64_t x, int64_t y, int64_t width, int64_t height) {
    MMRect rect = MMRectMake(x, y, width, height);
    MMBitmapRef bitmap = copyMMBitmapFromDisplayInRect(rect);
    
    if (bitmap == NULL) {
        return NULL;
    }
    
    // Create our wrapper struct
    CUBitmap* result = malloc(sizeof(CUBitmap));
    if (result == NULL) {
        destroyMMBitmap(bitmap);
        return NULL;
    }
    
    // Copy bitmap data
    size_t data_size = bitmap->bytewidth * bitmap->height;
    result->data = malloc(data_size);
    if (result->data == NULL) {
        free(result);
        destroyMMBitmap(bitmap);
        return NULL;
    }
    
    memcpy(result->data, bitmap->imageBuffer, data_size);
    result->width = bitmap->width;
    result->height = bitmap->height;
    result->bytewidth = bitmap->bytewidth;
    result->bitsPerPixel = bitmap->bitsPerPixel;
    result->bytesPerPixel = bitmap->bytesPerPixel;
    
    destroyMMBitmap(bitmap);
    return result;
}

#ifdef __APPLE__
#include "TargetConditionals.h"
#include "screencapturekit_bridge.h"
#endif

CUBitmap* cu_screen_capture_full(void) {
#ifdef __APPLE__
#if TARGET_OS_OSX
    // Try ScreenCaptureKit first (macOS 12.3+). If NULL, fall back.
    CUBitmap* sck = copyBitmapFullDisplay_SCK();
    if (sck != NULL) {
        return sck;
    }
#endif
#endif
    MMSize size = getMainDisplaySize();
    return cu_screen_capture_region(0, 0, size.width, size.height);
}

// JPEG screenshot functions with resizing
uint8_t* cu_screen_capture_region_jpeg(int64_t x, int64_t y, int64_t width, int64_t height, 
                                       int32_t maxSmallDim, int32_t maxLargeDim, 
                                       int32_t quality, int64_t* outSize) {
#ifdef __APPLE__
#if TARGET_OS_OSX
    // Use ScreenCaptureKit for JPEG with resizing
    return copyBitmapRegionJpeg_SCK(x, y, width, height, maxSmallDim, maxLargeDim, quality, outSize);
#endif
#endif
    // Fallback: not implemented for other platforms yet
    if (outSize) *outSize = 0;
    return NULL;
}

uint8_t* cu_screen_capture_full_jpeg(int32_t maxSmallDim, int32_t maxLargeDim, 
                                     int32_t quality, int64_t* outSize) {
#ifdef __APPLE__
#if TARGET_OS_OSX
    // Use ScreenCaptureKit for JPEG with resizing
    return copyBitmapFullJpeg_SCK(maxSmallDim, maxLargeDim, quality, outSize);
#endif
#endif
    // Fallback: not implemented for other platforms yet
    if (outSize) *outSize = 0;
    return NULL;
}

void cu_screen_free_jpeg(uint8_t* data) {
#ifdef __APPLE__
#if TARGET_OS_OSX
    freeJpegData_SCK(data);
    return;
#endif
#endif
    // Fallback
    if (data) {
        free(data);
    }
}

void cu_screen_free_capture(CUBitmap* bitmap) {
    if (bitmap != NULL) {
        if (bitmap->data != NULL) {
            free(bitmap->data);
        }
        free(bitmap);
    }
}

// Utility functions
void cu_sleep_ms(int milliseconds) {
    microsleep((double)milliseconds);
}