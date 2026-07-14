import Domain
import Foundation

extension MockData {
    /// Photo-sharing consent, separate from `consentByEngagement()` (outcome
    /// derivation). Only Morgan Chen (engagement 1) has granted it — every
    /// other engagement defaults to withheld, so the Progress screen's
    /// consent gate has real seeded cases to hide behind.
    static func photoConsentByEngagement() -> [Identifier<Engagement>: Bool] {
        [
            engagementID(1): true,
            engagementID(2): false,
            engagementID(3): false,
            engagementID(4): false,
            engagementID(5): false,
            engagementID(6): false,
            engagementID(7): false
        ]
    }

    /// A couple of seeded `ProgressPhoto` references for Morgan Chen
    /// (engagement 1), the one engagement with photo consent granted.
    /// References are opaque strings — `InMemoryStore` has no real photo
    /// assets, so these are only ever used as stable keys for a placeholder
    /// tile in the UI, never decoded as image data.
    static func seedProgressPhotos() -> [ProgressPhoto] {
        [
            ProgressPhoto(
                id: Identifier(uuid(20, 0)),
                engagementID: engagementID(1),
                reference: "mock-photo-morgan-1",
                capturedAt: date(-60),
                source: .clientSelfReported
            ),
            ProgressPhoto(
                id: Identifier(uuid(20, 1)),
                engagementID: engagementID(1),
                reference: "mock-photo-morgan-2",
                capturedAt: date(-10),
                source: .clientSelfReported
            )
        ]
    }
}
