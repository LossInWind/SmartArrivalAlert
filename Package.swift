// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartArrivalAlert",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SmartArrivalAlert",
            targets: ["SmartArrivalAlert"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "SmartArrivalAlert",
            dependencies: [],
            path: "SmartArrivalAlert",
            exclude: ["Info.plist", "SmartArrivalAlertApp.swift", "ContentView.swift"],
            sources: ["Models", "Services", "Utilities", "ViewModels"]
        ),
        .testTarget(
            name: "SmartArrivalAlertTests",
            dependencies: [
                "SmartArrivalAlert",
                "SwiftCheck"
            ],
            path: "SmartArrivalAlertTests"
        ),
    ]
)
