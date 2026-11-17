// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LeapWispr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LeapWispr", targets: ["LeapWispr"])
    ],
    targets: [
        .executableTarget(
            name: "LeapWispr",
            path: "Sources/LeapWispr",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "LeapWisprTests",
            dependencies: ["LeapWispr"]
        ),
    ]
)
