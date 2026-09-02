# ParrotSDK (Swift Package)

Swift Package Manager (SPM) distribution of Parrot's Drone SDKs for iOS 26+ and Swift 6.2+.

## Overview

This repository packages the official Parrot drone SDK components into a single modular Swift Package:

- **`GroundSdk`** : High-level Swift API for drone piloting, telemetry, camera controls, and stream.
- **`ArsdkEngine`** : Protocol and communication engine for ARSDK.
- **`SdkCore`** : Low-level C/C++/Objective-C networking and device communication binary framework (`.xcframework`).
- **`OpenFlightCore`** : Core utilities and low-level models binary framework (`.xcframework`).

## Requirements

- **iOS 26.0+**
- **Xcode 16+ / Swift 6.2+**
- **SwiftProtobuf 1.28.0+**

## Installation

### Swift Package Manager

In Xcode, go to **File > Add Package Dependencies...** and add the repository URL or path:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/ParrotSDK.git", from: "1.0.0")
]
```

Or add as a local package:
```swift
dependencies: [
    .package(path: "../ParrotSDK")
]
```

Then add `GroundSdk`, `ArsdkEngine`, `SdkCore`, and `OpenFlightCore` to your target dependencies.

## License

BSD 3-Clause / Parrot Drones SAS.
