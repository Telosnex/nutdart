#include "../screengrab.h"
#include "../endian.h"
#include <stdlib.h> /* malloc() */

#include <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>

// Temporary stub implementation for macOS 15+ compatibility
// TODO: Implement using ScreenCaptureKit for proper macOS 15+ support
MMBitmapRef copyMMBitmapFromDisplayInRect(MMRect rect) {
    // Return NULL for now - screenshot functionality disabled on macOS 15+
    // This allows the rest of the library (mouse/keyboard) to work
    return NULL;
}
