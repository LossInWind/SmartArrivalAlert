// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedCode",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "SharedCode",
            targets: ["SharedCode"]),
    ],
    targets: [
        .target(
            name: "SharedCode"),
    ]
)
