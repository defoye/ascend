#if DEBUG

import DataInterfaces

/// The demo harness's final `Backend` decorator: forwards every repository
/// from whichever scenario backend `DemoScenarioFactory` built, and swaps in
/// `DemoPaymentGateway` so the control panel's payment-outcome picker
/// actually drives every charge — the same decorator pattern
/// `PaymentsModeBackend` already uses for `PaymentsMode` (see
/// docs/BUILD_STATUS.md).
struct DemoBackend: Backend {
    let wrapped: any Backend
    let paymentOutcomeController: DemoPaymentOutcomeController

    var people: any PersonRepository { wrapped.people }
    var professionals: any ProfessionalRepository { wrapped.professionals }
    var engagements: any EngagementRepository { wrapped.engagements }
    var programs: any ProgramRepository { wrapped.programs }
    var sessions: any SessionRepository { wrapped.sessions }
    var progress: any ProgressRepository { wrapped.progress }
    var progressPhotos: any ProgressPhotoRepository { wrapped.progressPhotos }
    var payments: any PaymentRepository { wrapped.payments }
    var messages: any MessageRepository { wrapped.messages }
    var outcomes: any OutcomeRepository { wrapped.outcomes }
    var notes: any NotesRepository { wrapped.notes }
    var availability: any AvailabilityRepository { wrapped.availability }
    var auth: any AuthGateway { wrapped.auth }
    var analytics: any AnalyticsTracking { wrapped.analytics }

    var paymentGateway: any PaymentGateway {
        DemoPaymentGateway(wrapped: wrapped.paymentGateway, controller: paymentOutcomeController)
    }
}

#endif
