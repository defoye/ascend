import ProjectDescription
import ProjectDescriptionHelpers

// Ascend — dependency rule (see docs/ARCHITECTURE.md):
//   App          -> Features, DesignSystem, InMemoryStore, DataInterfaces, Domain
//   Domain       -> (none; Foundation only)
//   DataInterfaces -> Domain
//   InMemoryStore  -> DataInterfaces, Domain
//   DesignSystem   -> (none)
//   Features       -> DesignSystem, DataInterfaces, Domain
//
// Add/remove files by editing the globs below, then run `tuist generate`.
// Never hand-edit the generated .xcodeproj / .xcworkspace.

let appInfoPlist: [String: InfoPlist.Value] = [
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "UILaunchScreen": .dictionary([:]),
    "UIApplicationSceneManifest": .dictionary([
        "UIApplicationSupportsMultipleScenes": .boolean(false),
    ]),
]

let appTarget = Target(
    name: "Ascend",
    platform: .iOS,
    product: .app,
    bundleId: "com.ascend.Ascend",
    deploymentTarget: AscendSettings.deploymentTarget,
    infoPlist: .extendingDefault(with: appInfoPlist),
    sources: ["App/Sources/**"],
    dependencies: [
        .target(name: "Features"),
        .target(name: "DesignSystem"),
        .target(name: "InMemoryStore"),
        .target(name: "DataInterfaces"),
        .target(name: "Domain"),
    ],
    settings: AscendSettings.settings
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

let designSystemTarget = Target.ascendFramework(name: "DesignSystem")
let designSystemTestsTarget = Target.ascendTests(name: "DesignSystemTests", testing: "DesignSystem")

let featuresTarget = Target.ascendFramework(
    name: "Features",
    dependencies: [
        .target(name: "DesignSystem"),
        .target(name: "DataInterfaces"),
        .target(name: "Domain"),
    ]
)
let featuresTestsTarget = Target.ascendTests(name: "FeaturesTests", testing: "Features")

let project = Project(
    name: "Ascend",
    organizationName: "Ascend",
    settings: AscendSettings.settings,
    targets: [
        appTarget,
        domainTarget,
        domainTestsTarget,
        dataInterfacesTarget,
        dataInterfacesTestsTarget,
        inMemoryStoreTarget,
        inMemoryStoreTestsTarget,
        designSystemTarget,
        designSystemTestsTarget,
        featuresTarget,
        featuresTestsTarget,
    ]
)
