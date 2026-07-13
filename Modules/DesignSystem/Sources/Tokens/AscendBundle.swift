import Foundation

/// Resolves the resource bundle that ships `Colors.xcassets` for this module.
///
/// Tuist can synthesize a `Bundle.module` accessor for targets with
/// resources, but its generated template (`static var module: Bundle = {
/// ... }()`) is mutable global state that fails Swift 6 strict concurrency
/// checking (see `Project.swift`, `resourceSynthesizers: []`). Instead this
/// resolves the bundle the same way that generated code would — via a class
/// compiled into this framework — but as a `let`-free computed property, so
/// there is no stored mutable global state to flag. Verified by building the
/// module after `tuist generate`.
enum AscendBundle {
    static var resources: Bundle { Bundle(for: BundleToken.self) }
}

private final class BundleToken {}
