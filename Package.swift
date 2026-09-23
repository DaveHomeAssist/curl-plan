// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CurlPlanCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CurlPlanCore", targets: ["CurlPlanCore"])
    ],
    targets: [
        .target(
            name: "CurlPlanCore",
            path: "ios/CurlPlan",
            exclude: [
                "Assets.xcassets",
                "Components.swift",
                "ComposeSheet.swift",
                "CurlPlanApp.swift",
                "CurlerProfileView.swift",
                "Info.plist",
                "Clubs.generated.swift",
                "AuthView.swift",
                "LockerRoomView.swift",
                "Merge.swift",
                "MessageThreadView.swift",
                "PassportView.swift",
                "PrivacyInfo.xcprivacy",
                "RootView.swift",
                "RosterView.swift",
                "SettingsSheet.swift",
                "SpielsView.swift",
                "StopDetailView.swift",
                "Theme.swift"
            ],
            sources: [
                "AccountBackendAPI.swift",
                "AccountHTTPBackend.swift",
                "AccountRuntime.swift",
                "AccountSocialContracts.swift",
                "Models.swift",
                "Seed.generated.swift"
            ]
        ),
        .testTarget(
            name: "CurlPlanCoreTests",
            dependencies: ["CurlPlanCore"],
            path: "tests/CurlPlanCoreTests"
        )
    ]
)
