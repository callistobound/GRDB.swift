// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let darwinPlatforms: [Platform] = [
    .iOS,
    .macOS,
    .macCatalyst,
    .tvOS,
    .visionOS,
    .watchOS,
]
var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_SNAPSHOT"),
    // Not all Linux distributions have support for WAL snapshots.
    .define("SQLITE_DISABLE_SNAPSHOT", .when(platforms: [.linux])),
]
var cSettings: [CSetting] = []
var dependencies: [PackageDescription.Package.Dependency] = [
    // Android only (see `android` below).
    .package(url: "https://github.com/skiptools/swift-sqlcipher", from: "1.9.0"),
]

// Android: the NDK has no SQLite, so GRDB uses swift-sqlcipher's (SQLite with FTS5), through the sources'
// `#elseif SQLCipher` imports. Apple platforms and Linux keep the system SQLite (GRDBSQLite).
//
// Skip sets TARGET_OS_ANDROID=1 when it builds for Android. The platform conditions alone aren't enough: Xcode
// still builds a dependency conditioned on Android, and passes its headers to GRDB, so GRDBSQLite's
// `#include <sqlite3.h>` would find swift-sqlcipher's sqlite3.h. So unless TARGET_OS_ANDROID is set, GRDB doesn't
// depend on swift-sqlcipher at all, and nothing about the Apple build changes.
let android = (Context.environment["TARGET_OS_ANDROID"] ?? "0") != "0"
var sqliteDependencies: [Target.Dependency] = [
    .target(name: "GRDBSQLite", condition: .when(platforms: darwinPlatforms + [.linux])),
]
if android {
    swiftSettings.append(.define("SQLCipher", .when(platforms: [.android])))
    sqliteDependencies += [
        .product(name: "SQLCipher", package: "swift-sqlcipher", condition: .when(platforms: [.android])),
        .target(name: "GRDBSQLCipher", condition: .when(platforms: [.android])),
    ]
}

// Don't rely on those environment variables. They are ONLY testing conveniences:
// $ SQLITE_ENABLE_PREUPDATE_HOOK=1 make test_SPM
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_PREUPDATE_HOOK"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_PREUPDATE_HOOK"))
    cSettings.append(.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK"))
}

// The SPI_BUILDER environment variable enables documentation building
// on <https://swiftpackageindex.com/groue/GRDB.swift>. See
// <https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2122>
// for more information.
//
// SPI_BUILDER also enables the `make docs-localhost` command.
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

// GRDB+SQLCipher: Uncomment those lines
//dependencies.append(.package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.11.0"))
//cSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLCipher"))

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        // GRDB+SQLCipher: Delete the GRDBSQLite library
        .library(name: "GRDBSQLite", targets: ["GRDBSQLite"]),
        .library(name: "GRDB", targets: ["GRDB"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB"]),
    ],
    dependencies: dependencies,
    targets: [
        // GRDB+SQLCipher: Delete the GRDBSQLite target
        .systemLibrary(
            name: "GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        // Android only: swift-sqlcipher's SQLite (see `android` above).
        .target(
            name: "GRDBSQLCipher",
            dependencies: [.product(name: "SQLCipher", package: "swift-sqlcipher")]
        ),
        .target(
            name: "GRDB",
            // The system SQLite everywhere but Android (see `android` above).
            dependencies: sqliteDependencies,
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/Core/DatabasePool/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/Private/InflectionsTests.json"),
                .copy("GRDBTests/ValueObservation/Issue1383.sqlite"),
                .copy("GRDBTests/GRDBCipher/db.SQLCipher3"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
