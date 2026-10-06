// swift-tools-version: 6.0
import PackageDescription

// Core engine as a package so it can be built and tested from the command line
// (macOS or iOS simulator) without an Xcode project. The app target will compile
// PhotoCompress/ directly; Core has no UIKit dependency.
let package = Package(
    name: "PhotoCompress",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PhotoCompressCore", targets: ["PhotoCompressCore"])],
    targets: [
        .target(name: "PhotoCompressCore", path: "PhotoCompress/Core"),
        .testTarget(
            name: "PhotoCompressCoreTests",
            dependencies: ["PhotoCompressCore"],
            path: "Tests/PhotoCompressCoreTests"
        ),
    ]
)
