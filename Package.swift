// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rsync-builder",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
        .package(url: "https://github.com/EmergeTools/Pow", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0")
    ],
    targets: [
        .executableTarget(
            name: "rsync-builder",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Pow", package: "Pow"),
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/rsync-builder"
        )
    ]
)
