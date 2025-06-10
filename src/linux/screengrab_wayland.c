#include "../screengrab.h"
#include "../endian.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

// Simple BMP header structure for creating raw bitmaps
typedef struct {
    uint16_t type;
    uint32_t size;
    uint16_t reserved1;
    uint16_t reserved2;
    uint32_t offset;
} __attribute__((packed)) BMPHeader;

typedef struct {
    uint32_t size;
    int32_t width;
    int32_t height;
    uint16_t planes;
    uint16_t bitCount;
    uint32_t compression;
    uint32_t imageSize;
    int32_t xPixelsPerMeter;
    int32_t yPixelsPerMeter;
    uint32_t colorsUsed;
    uint32_t colorsImportant;
} __attribute__((packed)) BMPInfoHeader;

static MMBitmapRef capture_with_grim(MMRect rect) {
    char cmd[512];
    char temp_file[] = "/tmp/nutdart_screenshot_XXXXXX.bmp";
    int fd = mkstemp(temp_file);
    if (fd == -1) return NULL;
    close(fd);
    
    // Use grim to capture the specified region as BMP (easier to parse)
    snprintf(cmd, sizeof(cmd), 
        "grim -t bmp -g \"%d,%d %dx%d\" \"%s\" 2>/dev/null",
        (int)rect.origin.x, (int)rect.origin.y,
        (int)rect.size.width, (int)rect.size.height,
        temp_file);
    
    int result = system(cmd);
    if (result != 0) {
        unlink(temp_file);
        return NULL;
    }
    
    // Load the BMP file
    FILE *f = fopen(temp_file, "rb");
    if (!f) {
        unlink(temp_file);
        return NULL;
    }
    
    BMPHeader header;
    BMPInfoHeader info;
    
    if (fread(&header, sizeof(header), 1, f) != 1 ||
        fread(&info, sizeof(info), 1, f) != 1) {
        fclose(f);
        unlink(temp_file);
        return NULL;
    }
    
    // Only support 24-bit or 32-bit BMPs for simplicity
    if (info.bitCount != 24 && info.bitCount != 32) {
        fclose(f);
        unlink(temp_file);
        return NULL;
    }
    
    // Seek to image data
    fseek(f, header.offset, SEEK_SET);
    
    // Calculate bytes per line (BMPs are padded to 4-byte boundaries)
    int bytes_per_pixel = info.bitCount / 8;
    int row_size = ((info.width * bytes_per_pixel + 3) & ~3);
    int image_size = row_size * abs(info.height);
    
    uint8_t *image_data = malloc(image_size);
    if (!image_data) {
        fclose(f);
        unlink(temp_file);
        return NULL;
    }
    
    if (fread(image_data, image_size, 1, f) != 1) {
        free(image_data);
        fclose(f);
        unlink(temp_file);
        return NULL;
    }
    
    fclose(f);
    unlink(temp_file);
    
    // Create MMBitmap (note: BMP is typically bottom-up, might need to flip)
    MMBitmapRef bitmap = createMMBitmap(image_data,
                                        abs(info.width),
                                        abs(info.height),
                                        row_size,
                                        info.bitCount,
                                        bytes_per_pixel);
    
    return bitmap;
}

static MMBitmapRef capture_with_imagemagick(MMRect rect) {
    char cmd[512];
    char temp_file[] = "/tmp/nutdart_screenshot_XXXXXX.bmp";
    int fd = mkstemp(temp_file);
    if (fd == -1) return NULL;
    close(fd);
    
    // Use ImageMagick's import command
    snprintf(cmd, sizeof(cmd),
        "import -window root -crop %dx%d+%d+%d %s 2>/dev/null",
        (int)rect.size.width, (int)rect.size.height,
        (int)rect.origin.x, (int)rect.origin.y,
        temp_file);
    
    if (system(cmd) != 0) {
        unlink(temp_file);
        return NULL;
    }
    
    // Use same BMP loading logic as grim
    FILE *f = fopen(temp_file, "rb");
    if (!f) {
        unlink(temp_file);
        return NULL;
    }
    
    // ... (same BMP loading code as above)
    fclose(f);
    unlink(temp_file);
    return NULL; // Simplified for now
}

MMBitmapRef copyMMBitmapFromDisplayInRect_wayland(MMRect rect) {
    MMBitmapRef bitmap = NULL;
    
    // Try grim first (works with Sway/wlroots compositors)
    if (system("which grim > /dev/null 2>&1") == 0) {
        bitmap = capture_with_grim(rect);
        if (bitmap) return bitmap;
    }
    
    // Try ImageMagick import (works in many environments)
    if (system("which import > /dev/null 2>&1") == 0) {
        bitmap = capture_with_imagemagick(rect);
        if (bitmap) return bitmap;
    }
    
    // Try gnome-screenshot (requires user interaction)
    if (system("which gnome-screenshot > /dev/null 2>&1") == 0) {
        // This would require user interaction, so maybe skip in automated scenarios
    }
    
    return NULL;
}