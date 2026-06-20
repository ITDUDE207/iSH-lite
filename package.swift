// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iSHLite",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "iSHLite", targets: ["iSHLite"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "iSHLite",
            dependencies: [],
            path: "Sources/iSHLite"
        )
    ]
)
