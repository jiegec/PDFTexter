// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "PDFTexter",
    platforms: [
	.macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.3"),
    ],
    targets: [
        .target(
            name: "PDFTexter",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]),
    ]
)