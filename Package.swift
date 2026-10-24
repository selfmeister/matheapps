// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MatheAppsMathCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MathCore", targets: ["MathCore"])
    ],
    targets: [
        .target(name: "MathCore"),
        .testTarget(
            name: "MathCoreTests",
            dependencies: ["MathCore"]
        )
    ]
)
