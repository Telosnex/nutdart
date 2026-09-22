// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nutdart",
    platforms: [.macOS("10.14")],
    products: [
        // Dart loads nutdart.framework/nutdart through dart:ffi.
        .library(name: "nutdart", type: .dynamic, targets: ["nutdart"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "nutdart",
            dependencies: [
                "nutdart_noarc",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/nutdart",
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .target(
            name: "nutdart_noarc",
            path: "Sources/nutdart_noarc",
            publicHeadersPath: ".",
            cSettings: [.unsafeFlags(["-fno-objc-arc"])]
        )
    ]
)
