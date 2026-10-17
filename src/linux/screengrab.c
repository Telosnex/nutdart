#include "../screengrab.h"
#include "../endian.h"
#include <stdlib.h> /* malloc() */
#include <string.h>
#include <unistd.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include "../xdisplay.h"

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
   // A Wayland session has no synchronous capture. XWayland shows only X11
   // windows. Use the asynchronous portal API (PortalComputerUse) instead.
   if (is_wayland_session()) return NULL;

   return copyMMBitmapFromDisplayInRect_x11(rect);
}
