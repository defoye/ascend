import Foundation
import Testing
@testable import Domain

@Suite("EngagementInvite")
struct EngagementInviteTests {
    private static let allowedAlphabet = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    @Test("generateCode produces 8 characters, all from the unambiguous alphabet")
    func generateCodeProducesEightAllowedCharacters() {
        let code = EngagementInvite.generateCode()
        #expect(code.count == 8)
        #expect(code.allSatisfy { Self.allowedAlphabet.contains($0) })
    }

    @Test("generateCode excludes ambiguous glyphs: I, L, O, 0, 1")
    func generateCodeExcludesAmbiguousGlyphs() {
        let code = EngagementInvite.generateCode()
        let ambiguous = Set("ILO01")
        #expect(code.allSatisfy { !ambiguous.contains($0) })
    }

    @Test("two generated codes differ (probabilistic)")
    func twoGeneratedCodesDiffer() {
        let first = EngagementInvite.generateCode()
        let second = EngagementInvite.generateCode()
        #expect(first != second)
    }

    @Test("normalize trims whitespace and uppercases")
    func normalizeTrimsAndUppercases() {
        #expect(EngagementInvite.normalize("  k7m2pqxr  ") == "K7M2PQXR")
        #expect(EngagementInvite.normalize("K7M2PQXR") == "K7M2PQXR")
    }

    @Test("isClaimed reflects whether claimedByPersonID is set")
    func isClaimedReflectsClaimState() {
        let unclaimed = EngagementInvite(
            id: Identifier(),
            code: "K7M2PQXR",
            professionalID: Identifier(),
            suggestedClientName: nil,
            createdAt: Date(),
            claimedByPersonID: nil,
            claimedAt: nil,
            engagementID: nil
        )
        #expect(!unclaimed.isClaimed)

        let claimed = EngagementInvite(
            id: unclaimed.id,
            code: unclaimed.code,
            professionalID: unclaimed.professionalID,
            suggestedClientName: nil,
            createdAt: unclaimed.createdAt,
            claimedByPersonID: Identifier(),
            claimedAt: Date(),
            engagementID: Identifier()
        )
        #expect(claimed.isClaimed)
    }
}
