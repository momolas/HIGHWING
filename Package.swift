// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ParrotSDK",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "GroundSdk", targets: ["GroundSdk"]),
        .library(name: "ArsdkEngine", targets: ["ArsdkEngine"]),
        .library(name: "SdkCore", targets: ["SdkCore"]),
        .library(name: "OpenFlightCore", targets: ["OpenFlightCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0")
    ],
    targets: [
        .binaryTarget(
            name: "SdkCore",
            path: "Frameworks/SdkCore.xcframework"
        ),
        .binaryTarget(
            name: "OpenFlightCore",
            path: "Frameworks/OpenFlightCore.xcframework"
        ),
        .target(
            name: "ArsdkEngine",
            dependencies: [
                "SdkCore",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/ArsdkEngine"
        ),
        .target(
            name: "GroundSdk",
            dependencies: [
                "SdkCore",
                "ArsdkEngine",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/GroundSdk"
        )
    ]
)
