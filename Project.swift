import ProjectDescription
import ProjectDescriptionHelpers

// Ascend — dependency rule (see docs/ARCHITECTURE.md):
//   App          -> Features, DesignSystem, InMemoryStore, SupabaseBackend, DataInterfaces, Domain
//   Domain       -> (none; Foundation only)
//   DataInterfaces -> Domain
//   InMemoryStore  -> DataInterfaces, Domain
//   SupabaseBackend -> DataInterfaces, Domain, supabase-swift (package; App-only production adapter)
//   DesignSystem   -> (none)
//   Features       -> DesignSystem, DataInterfaces, Domain
//
// Add/remove files by editing the globs below, then run `tuist generate`.
// Never hand-edit the generated .xcodeproj / .xcworkspace.

let appInfoPlist: [String: InfoPlist.Value] = [
    "CFBundleShortVersionString": "0.1.0",
    "CFBundleVersion": "1",
    "UILaunchScreen": .dictionary([
        "UIColorName": .string("LaunchBackground"),
    ]),
    "UIApplicationSceneManifest": .dictionary([
        "UIApplicationSupportsMultipleScenes": .boolean(false),
    ]),
    // Supabase configuration (see docs/BACKEND.md, Config/Secrets.xcconfig).
    // Only populated in Release, where SupabaseBackend is the composition
    // root's backend — Debug has no xcconfig backing these keys (Debug always
    // uses InMemoryStore, never reads them) and Xcode substitutes an empty
    // string for an undefined build setting, which is fine.
    "SUPABASE_URL": .string("$(SUPABASE_URL)"),
    "SUPABASE_ANON_KEY": .string("$(SUPABASE_ANON_KEY)"),
]

// App Store Connect requires an explicit app-icon asset-catalog name (Xcode
// project templates set this automatically; Tuist-generated targets need it
// spelled out) — see App/Resources/Assets.xcassets/AppIcon.appiconset.
//
// Only the Release configuration is backed by Config/Secrets.xcconfig
// (gitignored, owner-provided — see docs/BACKEND.md): Debug intentionally has
// no xcconfig here so a fresh checkout without Supabase credentials still
// builds and runs Debug (InMemoryStore, $0, offline) with zero setup.
let appSettings: Settings = .settings(
    base: AscendSettings.base.merging(["ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon"]) { _, new in new },
    configurations: [
        .debug(name: "Debug"),
        .release(name: "Release", xcconfig: "Config/Secrets.xcconfig"),
    ],
    defaultSettings: .recommended
)

let appTarget = Target(
    name: "Ascend",
    platform: .iOS,
    product: .app,
    bundleId: "com.ascend.Ascend",
    deploymentTarget: AscendSettings.deploymentTarget,
    infoPlist: .extendingDefault(with: appInfoPlist),
    sources: ["App/Sources/**"],
    resources: ["App/Resources/**"],
    dependencies: [
        .target(name: "Features"),
        .target(name: "DesignSystem"),
        .target(name: "InMemoryStore"),
        .target(name: "SupabaseBackend"),
        .target(name: "DataInterfaces"),
        .target(name: "Domain"),
    ],
    settings: appSettings
)

let domainTarget = Target.ascendFramework(name: "Domain")
let domainTestsTarget = Target.ascendTests(name: "DomainTests", testing: "Domain")

let dataInterfacesTarget = Target.ascendFramework(
    name: "DataInterfaces",
    dependencies: [.target(name: "Domain")]
)
let dataInterfacesTestsTarget = Target.ascendTests(name: "DataInterfacesTests", testing: "DataInterfaces")

let inMemoryStoreTarget = Target.ascendFramework(
    name: "InMemoryStore",
    dependencies: [.target(name: "DataInterfaces"), .target(name: "Domain")]
)
let inMemoryStoreTestsTarget = Target.ascendTests(name: "InMemoryStoreTests", testing: "InMemoryStore")

// SupabaseBackend: the production `Backend` adapter (see docs/BACKEND.md,
// docs/ARCHITECTURE.md). Only this module depends on the supabase-swift
// package — Domain/DataInterfaces/InMemoryStore/Features stay backend-agnostic,
// and only the `Ascend` App composition root depends on this module.
let supabaseBackendTarget = Target.ascendFramework(
    name: "SupabaseBackend",
    dependencies: [
        .target(name: "DataInterfaces"),
        .target(name: "Domain"),
        .package(product: "Supabase"),
    ]
)
let supabaseBackendTestsTarget = Target.ascendTests(name: "SupabaseBackendTests", testing: "SupabaseBackend")

// A SEPARATE, skippable integration-test target: it round-trips real data
// against a live Supabase project when SUPABASE_URL/SUPABASE_ANON_KEY are
// present in the environment, and no-ops cleanly (no failures) otherwise —
// see Modules/SupabaseBackend/IntegrationTests/README in-file docs. Never
// runs live in CI/local default `xcodebuild test` because it requires the
// owner's live project credentials to do anything beyond skip.
let supabaseBackendIntegrationTestsTarget = Target(
    name: "SupabaseBackendIntegrationTests",
    platform: .iOS,
    product: .unitTests,
    bundleId: "com.ascend.SupabaseBackendIntegrationTests",
    deploymentTarget: AscendSettings.deploymentTarget,
    infoPlist: .default,
    sources: ["Modules/SupabaseBackend/IntegrationTests/**"],
    dependencies: [
        .target(name: "SupabaseBackend"),
        .target(name: "DataInterfaces"),
        .target(name: "Domain"),
    ],
    settings: AscendSettings.settings
)

let designSystemTarget = Target.ascendFramework(
    name: "DesignSystem",
    resources: ["Modules/DesignSystem/Resources/**"]
)
let designSystemTestsTarget = Target.ascendTests(name: "DesignSystemTests", testing: "DesignSystem")

let featuresTarget = Target.ascendFramework(
    name: "Features",
    dependencies: [
        .target(name: "DesignSystem"),
        .target(name: "DataInterfaces"),
        .target(name: "Domain"),
    ]
)
let featuresTestsTarget = Target.ascendTests(
    name: "FeaturesTests",
    testing: "Features",
    additionalDependencies: [.target(name: "InMemoryStore"), .target(name: "Domain")]
)

// Tuist's default synthesized resource accessors (Bundle.module, an Assets
// enum, etc. — see `Derived/Sources/Tuist*+DesignSystem.swift`) predate
// Swift 6 strict concurrency and emit non-Sendable-static-state errors under
// this project's "complete" checking. DesignSystem hand-writes its own
// bundle/color accessors (see Modules/DesignSystem/Sources/Tokens), so
// synthesis is disabled project-wide.
let project = Project(
    name: "Ascend",
    organizationName: "Ascend",
    options: .options(
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    packages: [
        .package(url: "https://github.com/supabase/supabase-swift", .upToNextMajor(from: "2.51.0")),
    ],
    settings: AscendSettings.settings,
    targets: [
        appTarget,
        domainTarget,
        domainTestsTarget,
        dataInterfacesTarget,
        dataInterfacesTestsTarget,
        inMemoryStoreTarget,
        inMemoryStoreTestsTarget,
        supabaseBackendTarget,
        supabaseBackendTestsTarget,
        supabaseBackendIntegrationTestsTarget,
        designSystemTarget,
        designSystemTestsTarget,
        featuresTarget,
        featuresTestsTarget,
    ],
    resourceSynthesizers: []
)
