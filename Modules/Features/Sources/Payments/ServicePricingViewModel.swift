import DataInterfaces
import Domain
import Foundation
import Observation

/// Lets a coach edit the `priceCents` of each `Service` on their own
/// `ProfessionalProfile` and persist the change through
/// `ProfessionalRepository.upsert(_:)`.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ServicePricingViewModel {
    public private(set) var profile: ProfessionalProfile?
    /// Draft prices, in whole currency units (e.g. dollars) as display text,
    /// keyed by service id — bound to text fields in `ServicePricingView`.
    public var draftPrices: [Identifier<Service>: String] = [:]
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var loadErrorMessage: String?
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(backend: any Backend, professionalID: Identifier<Person>) {
        self.backend = backend
        self.professionalID = professionalID
    }

    public var services: [Service] { profile?.services ?? [] }

    /// Loads this professional's `ProfessionalProfile` and seeds
    /// `draftPrices` from its current service prices.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await backend.professionals.profile(forProfessional: professionalID)
            self.profile = profile
            draftPrices = Dictionary(
                uniqueKeysWithValues: (profile?.services ?? []).map { ($0.id, Self.displayString(forCents: $0.priceCents)) }
            )
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your services. Pull to refresh to try again."
        }
    }

    /// Parses each service's entry in `draftPrices` as a dollar amount,
    /// rewrites that service's `priceCents`, and persists the whole
    /// profile. Entries that don't parse to a non-negative number are left
    /// unchanged rather than blocking the save of the others.
    @discardableResult
    public func save() async -> Bool {
        guard let profile else { return false }
        isSaving = true
        defer { isSaving = false }

        let updatedServices = profile.services.map { service -> Service in
            guard let text = draftPrices[service.id], let dollars = Double(text), dollars >= 0 else { return service }
            return Service(
                id: service.id,
                category: service.category,
                title: service.title,
                priceCents: Int((dollars * 100).rounded()),
                currency: service.currency,
                modality: service.modality
            )
        }
        let updatedProfile = ProfessionalProfile(
            id: profile.id,
            personID: profile.personID,
            displayName: profile.displayName,
            headline: profile.headline,
            bio: profile.bio,
            services: updatedServices,
            verifications: profile.verifications
        )
        do {
            self.profile = try await backend.professionals.upsert(updatedProfile)
            draftPrices = Dictionary(
                uniqueKeysWithValues: updatedServices.map { ($0.id, Self.displayString(forCents: $0.priceCents)) }
            )
            saveErrorMessage = nil
            return true
        } catch {
            saveErrorMessage = "Couldn't save your prices. Try again."
            return false
        }
    }

    static func displayString(forCents cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
    }
}
