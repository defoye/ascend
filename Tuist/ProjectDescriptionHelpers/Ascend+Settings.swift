import ProjectDescription

/// Shared build settings and helpers for the Ascend Tuist project.
///
/// All modules target iOS 18.0 and build under Swift 6 with complete
/// strict concurrency checking.
public enum AscendSettings {
    public static let deploymentTarget: DeploymentTarget = .iOS(targetVersion: "18.0", devices: [.iphone, .ipad])

    public static let base: SettingsDictionary = [
        "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete",
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        // Xcode's automatic asset-catalog Swift symbol generation
        // (`GeneratedAssetSymbols.swift`) predates Swift 6 strict
        // concurrency and emits non-Sendable-static-state errors under
        // "complete" checking. Modules hand-write their own color/resource
        // accessors instead (see Modules/DesignSystem/Sources/Tokens).
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOLS": "NO",
    ]

    public static var settings: Settings {
        .settings(base: base, defaultSettings: .recommended)
    }
}

extension Target {
    /// A framework target following Ascend's module conventions:
    /// sources at `Modules/<name>/Sources/**`, bundle id `com.ascend.<name>`.
    public static func ascendFramework(
        name: String,
        dependencies: [TargetDependency] = [],
        resources: ResourceFileElements? = nil
    ) -> Target {
        Target(
            name: name,
            platform: .iOS,
            product: .framework,
            bundleId: "com.ascend.\(name)",
            deploymentTarget: AscendSettings.deploymentTarget,
            infoPlist: .default,
            sources: ["Modules/\(name)/Sources/**"],
            resources: resources,
            dependencies: dependencies,
            settings: AscendSettings.settings
        )
    }

    /// A unit test target for an Ascend framework module.
    public static func ascendTests(
        name: String,
        testing moduleName: String
    ) -> Target {
        Target(
            name: name,
            platform: .iOS,
            product: .unitTests,
            bundleId: "com.ascend.\(name)",
            deploymentTarget: AscendSettings.deploymentTarget,
            infoPlist: .default,
            sources: ["Modules/\(moduleName)/Tests/**"],
            dependencies: [.target(name: moduleName)],
            settings: AscendSettings.settings
        )
    }
}
