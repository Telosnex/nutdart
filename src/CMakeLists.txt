cmake_minimum_required(VERSION 3.10)

project(nutdart VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

# Platform detection
if(WIN32)
    set(PLATFORM_NAME "win32")
elseif(APPLE)
    set(PLATFORM_NAME "macos")
elseif(UNIX)
    set(PLATFORM_NAME "linux")
endif()

# Source files from libnut-core
set(COMMON_SOURCES
    nutdart.c
    deadbeef_rand.c
    MMBitmap.c
)

# Platform-specific sources
if(WIN32)
    set(PLATFORM_SOURCES
        win32/keycode.c
        win32/keypress.c
        win32/mouse.c
        win32/screen.c
        win32/screengrab.c
        win32/screengrab_jpeg.c
        win32/highlightwindow.c
        win32/window_manager.cc
    )
    set(PLATFORM_LIBS user32 gdi32 ole32 windowscodecs)
elseif(APPLE)
    set(PLATFORM_SOURCES
        macos/keycode.c
        macos/keypress.c
        macos/mouse.c
        macos/screen.c
        macos/screengrab.m
        macos/mouse_utils.mm
        macos/window_manager.mm
        macos/highlightwindow.m
        macos/screencapturekit_objc.m
    )
    find_library(CARBON_FRAMEWORK Carbon)
    find_library(COCOA_FRAMEWORK Cocoa)
    find_library(CORE_GRAPHICS_FRAMEWORK CoreGraphics)
    find_library(CORE_FOUNDATION_FRAMEWORK CoreFoundation)
    find_library(APPLICATION_SERVICES_FRAMEWORK ApplicationServices)
    find_library(IOKIT_FRAMEWORK IOKit)
    find_library(SCREENCAPTUREKIT_FRAMEWORK ScreenCaptureKit)
    find_library(AVFOUNDATION_FRAMEWORK AVFoundation)
    set(PLATFORM_LIBS
        ${CARBON_FRAMEWORK}
        ${COCOA_FRAMEWORK}
        ${CORE_GRAPHICS_FRAMEWORK}
        ${CORE_FOUNDATION_FRAMEWORK}
        ${APPLICATION_SERVICES_FRAMEWORK}
        ${IOKIT_FRAMEWORK}
        ${SCREENCAPTUREKIT_FRAMEWORK}
        ${AVFOUNDATION_FRAMEWORK}
    )
elseif(UNIX)
    set(PLATFORM_SOURCES
        linux/keycode.c
        linux/keypress.c
        linux/mouse.c
        linux/screen.c
        linux/screengrab.c
        linux/screengrab_jpeg.c
        linux/window_manager.cc
        linux/xdisplay.c
    )
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(X11 REQUIRED x11)
    pkg_check_modules(XTST REQUIRED xtst)
    pkg_check_modules(XINERAMA REQUIRED xinerama)
    pkg_check_modules(JPEG REQUIRED libjpeg)
    set(PLATFORM_LIBS ${X11_LIBRARIES} ${XTST_LIBRARIES} ${XINERAMA_LIBRARIES} ${JPEG_LIBRARIES})
    include_directories(${X11_INCLUDE_DIRS} ${XTST_INCLUDE_DIRS} ${XINERAMA_INCLUDE_DIRS} ${JPEG_INCLUDE_DIRS})
endif()

# Create the shared library
add_library(nutdart SHARED ${COMMON_SOURCES} ${PLATFORM_SOURCES})

# Include directories
target_include_directories(nutdart PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Link libraries
target_link_libraries(nutdart ${PLATFORM_LIBS})

target_compile_definitions(nutdart PUBLIC DART_SHARED_LIB)

# Output configuration
set_target_properties(nutdart PROPERTIES
    OUTPUT_NAME "nutdart"
)

# Windows-specific configuration for proper import library generation
if(WIN32)
    set_target_properties(nutdart PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS TRUE
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    )
    # Add COM definitions for WIC support
    target_compile_definitions(nutdart PRIVATE COBJMACROS CINTERFACE)
endif()

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(nutdart PRIVATE "-Wl,-z,max-page-size=16384")
endif()
