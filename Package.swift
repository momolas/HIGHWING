// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParrotKit",
    platforms: [
        .iOS(.v15)
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
            name: "GroundSdk",
            dependencies: [
                "SdkCore",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/GroundSdk"
        ),
        .target(
            name: "ArsdkEngine",
            dependencies: [
                "GroundSdk",
                "SdkCore",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources/ArsdkEngine"
        )
    ]
)
