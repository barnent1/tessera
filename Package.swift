// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tessera",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tessera", targets: ["Tessera"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Tessera",
            dependencies: ["SwiftTerm"],
            path: "sources/tessera"
        )
    ]
)
