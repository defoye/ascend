import Foundation

/// The public-facing profile of a professional: services offered and verification
/// evidence.
public struct ProfessionalProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<ProfessionalProfile>
    public let personID: Identifier<Person>
    public let displayName: String
    public let headline: String
    public let bio: String
    public let services: [Service]
    public let verifications: [Verification]

    public init(
        id: Identifier<ProfessionalProfile>,
        personID: Identifier<Person>,
        displayName: String,
        headline: String,
        bio: String,
        services: [Service],
        verifications: [Verification]
    ) {
        self.id = id
        self.personID = personID
        self.displayName = displayName
        self.headline = headline
        self.bio = bio
        self.services = services
        self.verifications = verifications
    }
}
