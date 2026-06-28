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
                "CurlPlanApp.swift",
                "CurlerProfileView.swift",
                "LiveMapView.swift",
                "LockerRoomView.swift",
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
                "Models.swift"
            ]
        ),
        .testTarget(
            name: "CurlPlanCoreTests",
            dependencies: ["CurlPlanCore"],
            path: "tests/CurlPlanCoreTests"
        )
    ]
)
