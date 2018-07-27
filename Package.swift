// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MongoKitten",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MongoKitten",
            targets: ["MongoKitten"]),
        .library(
            name: "GridFS",
            targets: ["GridFS"]),
    ],
    dependencies: [
        // For MongoDB Documents
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("develop/6.0/rewrite")),
        
        // Async
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.7.2"),
    ],
    targets: [
        .target(
            name: "_MongoKittenCrypto",
            dependencies: []),
        .target(
            name: "MongoKitten",
            dependencies: ["BSON", "NIO", "_MongoKittenCrypto"]),
        .target(
            name: "GridFS",
            dependencies: ["BSON", "MongoKitten", "NIO", "_MongoKittenCrypto"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
    ]
)

if #available(macOS 10.14, iOS 12, *) {
    package.dependencies.append(
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "0.1.0")
    )

    if let index = package.targets.firstIndex(where: { $0.name == "MongoKitten" }) {
        package.targets[index].dependencies.append("NIOTransportServices")
    }
}
