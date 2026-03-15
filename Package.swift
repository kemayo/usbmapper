// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsbMapper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "UsbMapper",
            path: "Sources/UsbMapper",
            exclude: ["Resources/Info.plist"],
            resources: [.copy("Resources/cyme")],
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
