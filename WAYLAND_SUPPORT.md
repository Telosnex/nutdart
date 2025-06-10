# Wayland Support for NutDart

## The Problem
libnut's original `screengrab.c` used X11's `XGetImage()` which doesn't work on Wayland because:
- Wayland doesn't expose the X11 protocol directly
- Wayland has stricter security (no arbitrary screen access)
- Different display server architecture

### What We've Added:

1. **Environment Detection**: Automatically detects if running on Wayland vs X11
2. **Fallback Chain**: Tries multiple capture methods in order of preference
3. **Wayland Support**: Uses external tools that work with Wayland compositors

### Capture Methods (in order of preference):

#### X11 Method (Original)
- **When**: X11 sessions, XWayland available
- **Pros**: Fast, direct, no dependencies
- **Cons**: Doesn't work on pure Wayland

#### Grim (Wayland - Recommended)
- **When**: Sway, wlroots-based compositors (i3, Hyprland, etc.)
- **Pros**: Fast, designed for Wayland, supports regions
- **Cons**: Only works with wlroots compositors
- **Install**: `sudo apt install grim` (Ubuntu) or `pacman -S grim` (Arch)

#### ImageMagick Import
- **When**: Available on most Linux systems  
- **Pros**: Widely available, works in many environments
- **Cons**: Slower, might have permission issues on Wayland

### File Structure:
```
src/linux/
├── screengrab.c          # Main entry point with auto-detection
├── screengrab_wayland.c  # Wayland-specific implementations
└── xdisplay.c           # X11 display management
```

## Testing Your Setup

1. **Build the project**:

2. **Test environment detection**:
   ```bash
   # Check your current session type
   echo $XDG_SESSION_TYPE
   echo $WAYLAND_DISPLAY
   ```

3. **Install Wayland tools** (Ubuntu/Debian):
   ```bash
   sudo apt install grim slurp  # For wlroots compositors
   # OR
   sudo apt install imagemagick  # More universal
   ```

## Compositor Compatibility

### ✅ Should Work:
- **Sway** (with grim)
- **Hyprland** (with grim)  
- **River** (with grim)
- **GNOME Wayland** (with ImageMagick/gnome-screenshot)
- **KDE Plasma Wayland** (with spectacle/ImageMagick)
- **Any compositor** running XWayland (fallback to X11 method)

### ❓ Might Need Additional Work:
- **Compositor-specific protocols** (could add direct Wayland protocol support)
- **Permission dialogs** (some methods may require user confirmation)

## Fallback Strategy

The code tries methods in this order:
1. **Wayland Detection** → Try Wayland-specific tools
2. **X11 Fallback** → Use original X11 method (works with XWayland)
3. **Graceful Failure** → Return NULL if all methods fail

### Optional: Desktop Portal Method (Most "Proper")
This would use the XDG Desktop Portal API which works across all compositors but requires user permission for each screenshot. This isn't tenable for computer use automation, so it was not included in the implementation.
