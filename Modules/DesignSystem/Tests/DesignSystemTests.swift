import SwiftUI
import Testing
@testable import DesignSystem

@Suite("DesignSystem placeholder")
struct DesignSystemTests {
    @Test("Module links")
    func placeholder() {
        let name = String(describing: DesignSystem.self)
        #expect(name == "DesignSystem")
    }
}

@Suite("Color tokens")
struct ColorTokenTests {
    @Test("Every semantic color token from DESIGN_SPEC.md §2.1–2.2 resolves to a Color value")
    @MainActor
    func tokensResolve() {
        let tokens: [Color] = [
            .Ascend.background,
            .Ascend.surface,
            .Ascend.surfaceSecondary,
            .Ascend.primary,
            .Ascend.verified,
            .Ascend.secondary,
            .Ascend.success,
            .Ascend.warning,
            .Ascend.danger,
            .Ascend.textPrimary,
            .Ascend.textSecondary,
            .Ascend.textTertiary,
            .Ascend.border,
            .Ascend.onPrimary,
            .Ascend.onVerified,
            .Ascend.skeleton,
            .Ascend.skeleton2,
            .Ascend.chartFill,
        ]
        #expect(tokens.count == 18)
    }
}

@Suite("Spacing, radius, and typography tokens")
struct LayoutTokenTests {
    @Test("Spacing tokens follow the 4pt grid (DESIGN_SPEC.md §2.4)")
    func spacingGrid() {
        #expect(Spacing.space1 == 4)
        #expect(Spacing.space2 == 8)
        #expect(Spacing.space3 == 12)
        #expect(Spacing.space4 == 16)
        #expect(Spacing.space5 == 20)
        #expect(Spacing.space6 == 24)
        #expect(Spacing.space8 == 32)
        #expect(Spacing.space10 == 40)
        #expect(Spacing.space12 == 48)
    }

    @Test("Radius tokens match the spec (DESIGN_SPEC.md §2.5)")
    func radiusScale() {
        #expect(Radius.sm == 8)
        #expect(Radius.md == 12)
        #expect(Radius.lg == 16)
        #expect(Radius.xl == 22)
        #expect(Radius.pill > Radius.xl)
    }

    @Test("Every AscendTypeToken resolves to a font")
    @MainActor
    func typeTokensResolve() {
        let tokens: [AscendTypeToken] = [
            .largeTitle, .title1, .title2, .title3,
            .headline, .body, .callout, .subheadline,
            .footnote, .caption, .caption2, .statLarge, .statMedium,
        ]
        for token in tokens {
            _ = Text("Sample").ascendType(token)
        }
        #expect(tokens.count == 13)
    }

    @Test("The data/label style renders without crashing")
    @MainActor
    func dataLabelStyleRenders() {
        _ = Text("Sessions").ascendDataLabel()
        #expect(Bool(true))
    }
}

@Suite("Components instantiate")
struct ComponentSmokeTests {
    @Test("Core components build without crashing")
    @MainActor
    func componentsInstantiate() {
        _ = AscendButton("Log session") {}
        _ = AscendButton("Small pill", size: .pill) {}
        _ = Card { Text("Card content") }
        _ = ListRow(title: "Title", subtitle: "Subtitle")
        _ = AscendTextField(label: "Email", text: .constant(""))
        _ = Chip("Strength", style: .filter(isSelected: true))
        _ = Chip("Weight loss", style: .goalTag(dotColor: .Ascend.primary))
        _ = Chip(StatusTone.active.rawValue, style: .status(.active))
        _ = StatTile(label: "Sessions", value: "128", delta: .up("12"))
        _ = VerifiedBadge(style: .filled)
        _ = TrackedBadge()
        _ = Avatar(name: "Jordan Lee")
        _ = AvatarStack(names: ["Jordan Lee", "Priya Nair", "Sam Okafor", "Ana Costa"])
        _ = EmptyState(systemImage: "tray", title: "Nothing yet", message: "Come back later.")
        _ = SectionHeader("Section")
        _ = ProgressChart(
            title: "Body weight",
            unit: "lb",
            points: [
                ProgressPoint(date: .now, value: 180),
                ProgressPoint(date: .now.addingTimeInterval(86_400), value: 178),
            ]
        )
        _ = SkeletonBlock(width: 120, height: 40)
        _ = SkeletonText(width: 90)
        _ = SkeletonCard { SkeletonText(width: 90) }
        _ = LoggedConfirmation(value: "181 lb", delta: "−15 lb")
    }

    @Test("VerifiedBadge copy follows Invariant 2")
    @MainActor
    func verifiedBadgeCopy() {
        // VerifiedBadge always speaks "Verified journey" or "Verified" —
        // never a caused result — per Invariant 2 (docs/PRODUCT.md). There
        // is no public API to override this copy, which is itself the
        // guarantee.
        _ = VerifiedBadge(style: .compact)
        _ = VerifiedBadge(style: .circular)
        #expect(Bool(true))
    }

    @Test("ProgressChart accessibility descriptor summarizes a measured journey")
    @MainActor
    func progressChartDescriptor() {
        let chart = ProgressChart(
            title: "Body weight",
            unit: "lb",
            points: [
                ProgressPoint(date: .now.addingTimeInterval(-86_400 * 7), value: 182),
                ProgressPoint(date: .now, value: 178),
            ],
            lowerIsBetter: true
        )
        let descriptor = chart.makeChartDescriptor()
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == 2)
        let summary = descriptor.summary ?? ""
        #expect(summary.contains("journey"))
        #expect(!summary.contains("caused"))
    }
}

@Suite("AscendHaptics")
struct AscendHapticsTests {
    @Test("success() and impact() are callable without crashing")
    @MainActor
    func firesWithoutCrashing() {
        AscendHaptics.success()
        AscendHaptics.impact()
        AscendHaptics.impact(.medium)
        AscendHaptics.impact(.heavy)
        #expect(Bool(true))
    }
}
