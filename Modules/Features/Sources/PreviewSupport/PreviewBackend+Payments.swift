import DataInterfaces
import Domain
import Foundation

// MARK: - Professional profile + payment gateway fixtures
//
// Split into their own file (rather than kept in `PreviewBackend.swift`)
// purely to stay under SwiftLint's `file_length` — SwiftLint measures each
// file independently.

struct PreviewProfessionalRepository: ProfessionalRepository {
    let professionalID: Identifier<Person>

    private var profile: ProfessionalProfile {
        ProfessionalProfile(
            id: Identifier(),
            personID: professionalID,
            displayName: "Jordan Ellis",
            headline: "Certified strength & weight-loss coach",
            bio: "Preview bio.",
            services: [
                Service(
                    id: Identifier(), category: .strengthTraining, title: "1:1 Strength Coaching",
                    priceCents: 15_000, currency: "USD", modality: .hybrid
                ),
                Service(
                    id: Identifier(), category: .weightLoss, title: "Weight Loss Program",
                    priceCents: 12_000, currency: "USD", modality: .virtual
                )
            ],
            verifications: []
        )
    }

    func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? { profile }
    func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? {
        personID == professionalID ? profile : nil
    }
    func listProfiles() async throws -> [ProfessionalProfile] { [profile] }
    func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile { profile }
    func delete(_ id: Identifier<ProfessionalProfile>) async throws {}
}

struct PreviewPaymentGateway: PaymentGateway {
    func charge(engagementID: Identifier<Engagement>, amountCents: Int, currency: String) async throws -> Payment {
        Payment(
            id: Identifier(),
            engagementID: engagementID,
            amountCents: amountCents,
            currency: currency,
            status: .succeeded,
            platformFeeCents: amountCents / 10,
            stripePaymentIntentID: nil,
            createdAt: Date()
        )
    }

    func refund(paymentID: Identifier<Payment>) async throws -> Payment {
        Payment(
            id: paymentID,
            engagementID: Identifier(),
            amountCents: 0,
            currency: "USD",
            status: .refunded,
            platformFeeCents: 0,
            stripePaymentIntentID: nil,
            createdAt: Date()
        )
    }
}
