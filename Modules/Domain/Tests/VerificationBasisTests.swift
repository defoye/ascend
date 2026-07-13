import Testing
@testable import Domain

@Suite("VerificationBasis")
struct VerificationBasisTests {
    @Test("isFullyVerified is true only when all four pillars hold")
    func isFullyVerifiedRequiresAllPillars() {
        let full = VerificationBasis(
            relationshipVerified: true,
            activityVerified: true,
            paymentVerified: true,
            consentGranted: true
        )
        #expect(full.isFullyVerified == true)

        let missingConsent = VerificationBasis(
            relationshipVerified: true,
            activityVerified: true,
            paymentVerified: true,
            consentGranted: false
        )
        #expect(missingConsent.isFullyVerified == false)

        let none = VerificationBasis(
            relationshipVerified: false,
            activityVerified: false,
            paymentVerified: false,
            consentGranted: false
        )
        #expect(none.isFullyVerified == false)
    }
}
