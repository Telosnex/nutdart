cmake_minimum_required(VERSION 3.10)

project(computer_use VERSION 0.0.1 LANGUAGES C CXX)

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
    computer_use.c
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
        win32/window_manager.cc
    )
    set(PLATFORM_LIBS user32 gdi32)
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
        linux/window_manager.cc
        linux/xdisplay.c
    )
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(X11 REQUIRED x11)
    pkg_check_modules(XTST REQUIRED xtst)
    pkg_check_modules(XINERAMA REQUIRED xinerama)
    set(PLATFORM_LIBS ${X11_LIBRARIES} ${XTST_LIBRARIES} ${XINERAMA_LIBRARIES})
    include_directories(${X11_INCLUDE_DIRS} ${XTST_INCLUDE_DIRS} ${XINERAMA_INCLUDE_DIRS})
endif()

# Create the shared library
add_library(computer_use SHARED ${COMMON_SOURCES} ${PLATFORM_SOURCES})

# Include directories
target_include_directories(computer_use PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Link libraries
target_link_libraries(computer_use ${PLATFORM_LIBS})

# TODO: Commented out below block while following https://codelabs.developers.google.com/codelabs/flutter-ffigen#4
# Compiler-specific flags
# if(WIN32)
#     target_compile_definitions(computer_use PRIVATE _CRT_SECURE_NO_WARNINGS)
# elseif(APPLE)
#     set_target_properties(computer_use PROPERTIES
#         MACOSX_RPATH TRUE
#         BUILD_WITH_INSTALL_RPATH TRUE
#     )
# endif()

target_compile_definitions(computer_use PUBLIC DART_SHARED_LIB)


# Output configuration
set_target_properties(computer_use PROPERTIES
    PUBLIC_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/computer_use.h"
    OUTPUT_NAME "computer_use"
)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(nutdart PRIVATE "-Wl,-z,max-page-size=16384")
endif()
