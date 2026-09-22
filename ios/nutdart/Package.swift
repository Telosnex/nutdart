// swift-tools-version: 5.9
import PackageDescription

// nutdart's API is a no-op on iOS; this target keeps the plugin available to
// Flutter's Swift Package Manager integration without linking desktop code.
let package = Package(
    name: "nutdart",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "nutdart", targets: ["nutdart"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "nutdart",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
            path: "Sources/nutdart",
            publicHeadersPath: "."
        )
    ]
)
