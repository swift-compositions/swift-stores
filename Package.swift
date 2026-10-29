// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-stores",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Stores",
            targets: ["Stores"]
        ),
        .library(
            name: "Stores Testing",
            targets: ["Stores Testing"]
        ),
    ],
    traits: [
        .trait(name: "StoresTesting", description: "Stores Testing and the dependencies only it needs")
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-store.git", branch: "main", traits: ["Algebra"]),
        .package(
            url: "https://github.com/swift-molecules/swift-tree-keyed.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-deque.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-queue.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dictionary.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dictionary-ordered.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-algebra.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-compositions/swift-effects.git", branch: "main"),
        .package(
            url: "https://github.com/swift-compositions/swift-observations.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-compositions/swift-dependencies.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-atoms/swift-clock.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Stores",
            dependencies: [
                .product(name: "Store", package: "swift-store"),
                .product(name: "Tree Keyed", package: "swift-tree-keyed"),
                .product(name: "Deque", package: "swift-deque"),
                .product(name: "Queue Primitive", package: "swift-queue"),
                .product(name: "Dictionary", package: "swift-dictionary"),
                .product(
                    name: "Dictionary Ordered",
                    package: "swift-dictionary-ordered"
                ),
                .product(name: "Algebra", package: "swift-algebra"),
                .product(name: "Effects", package: "swift-effects"),
                .product(name: "Observations", package: "swift-observations"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "Stores Testing",
            dependencies: [
                "Stores",
                .product(name: "Store", package: "swift-store"),
                .product(name: "Effects", package: "swift-effects"),
                .product(name: "Clock Concurrency", package: "swift-clock", condition: .when(traits: ["StoresTesting"])),
            ]
        ),
        .testTarget(
            name: "Stores Tests",
            dependencies: [
                "Stores",
                "Stores Testing",
                .product(name: "Algebra", package: "swift-algebra"),
            ]
        ),
        .testTarget(
            name: "Stores Testing Tests",
            dependencies: [
                "Stores",
                "Stores Testing",
                .product(name: "Clock Concurrency", package: "swift-clock"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
