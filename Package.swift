// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Suss",
    platforms: [
        .macOS(.v10_14),
    ],
    products: [
        .executable(name: "Suss", targets: ["Suss"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/colinta/Ashen.git", .branch("master")),
        .package(path: "../Ashen"),
    ],
    targets: [
        .target(name: "Suss", dependencies: ["Ashen"]),
    ]
    )
