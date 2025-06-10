#include "../screengrab.h"
#include "../endian.h"
#include <stdlib.h> /* malloc() */
#include <string.h>
#include <unistd.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include "../xdisplay.h"

// Forward declaration for Wayland support
MMBitmapRef copyMMBitmapFromDisplayInRect_wayland(MMRect rect);

static int is_wayland_session(void) {
    const char *session_type = getenv("XDG_SESSION_TYPE");
    const char *wayland_display = getenv("WAYLAND_DISPLAY");
    
    return (session_type && strcmp(session_type, "wayland") == 0) ||
           (wayland_display && strlen(wayland_display) > 0);
}

static MMBitmapRef copyMMBitmapFromDisplayInRect_x11(MMRect rect)
{
 MMBitmapRef bitmap;

 Display *display = XOpenDisplay(NULL);
 if (display == NULL) return NULL;
 
 XImage *image = XGetImage(display,
                           XDefaultRootWindow(display),
                           (int)rect.origin.x,
                           (int)rect.origin.y,
                           (unsigned int)rect.size.width,
                           (unsigned int)rect.size.height,
                           AllPlanes, ZPixmap);
 XCloseDisplay(display);
 if (image == NULL) return NULL;

 bitmap = createMMBitmap((uint8_t *)image->data,
                         rect.size.width,
                         rect.size.height,
                         (size_t)image->bytes_per_line,
                         (uint8_t)image->bits_per_pixel,
                         (uint8_t)image->bits_per_pixel / 8);
 image->data = NULL; /* Steal ownership of bitmap data so we don't have to
                      * copy it. */
 XDestroyImage(image);

 return bitmap;
}

MMBitmapRef copyMMBitmapFromDisplayInRect(MMRect rect)
{
   // First, try to detect if we're running on Wayland
   if (is_wayland_session()) {
       MMBitmapRef bitmap = copyMMBitmapFromDisplayInRect_wayland(rect);
       if (bitmap != NULL) {
           return bitmap;
       }
       // If Wayland capture failed, fall back to X11 (XWayland might be available)
   }
   
   // Use X11 method (works on X11 and XWayland)
   return copyMMBitmapFromDisplayInRect_x11(rect);
}
