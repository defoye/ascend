import Foundation

/// A single service a professional offers, with pricing and delivery modality.
public struct Service: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Service>
    public let category: ServiceCategory
    public let title: String
    public let priceCents: Int
    public let currency: String
    public let modality: Modality

    public init(
        id: Identifier<Service>,
        category: ServiceCategory,
        title: String,
        priceCents: Int,
        currency: String,
        modality: Modality
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.priceCents = priceCents
        self.currency = currency
        self.modality = modality
    }
}
