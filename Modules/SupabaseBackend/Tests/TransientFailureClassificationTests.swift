import Foundation
import Supabase
import Testing
@testable import SupabaseBackend

/// Pins `SupabaseTable.isTransientFailure`, the single gate every mutation
/// uses to decide what to do with a failed network write (see
/// `SupabaseTable.upsert`/`delete`): a *transient* failure (offline, timeout,
/// dropped connection) is queued in `OfflineWriteQueue` for later replay,
/// while a server *rejection* (RLS denial, constraint violation, bad request)
/// is rethrown to the caller immediately.
///
/// Getting this wrong is silent and severe in both directions:
/// - too broad (a server rejection classed as transient) → an RLS denial or
///   constraint violation gets swallowed into the retry queue and endlessly
///   re-attempted, never surfacing to the user;
/// - too narrow (a real offline error classed as a rejection) → a write the
///   user made offline throws instead of queueing, and is lost.
///
/// The classifier is `(error as NSError).domain == NSURLErrorDomain`, so these
/// tests assert the boundary from both sides. `SupabaseTable` is generic; the
/// static method is Row-independent, so any concrete Row parameterizes it.
@Suite("Transient-failure classification")
struct TransientFailureClassificationTests {
    private func isTransient(_ error: Error) -> Bool {
        SupabaseTable<PersonRow>.isTransientFailure(error)
    }

    @Test("offline (not connected) is transient → queued for replay")
    func offlineIsTransient() {
        #expect(isTransient(URLError(.notConnectedToInternet)))
    }

    @Test("timeout is transient → queued for replay")
    func timeoutIsTransient() {
        #expect(isTransient(URLError(.timedOut)))
    }

    @Test("connection dropped mid-request is transient → queued for replay")
    func connectionLostIsTransient() {
        #expect(isTransient(URLError(.networkConnectionLost)))
    }

    /// The load-bearing case: a PostgrestError is how a server rejection (RLS
    /// denial, constraint violation) reaches the adapter. It must NOT be
    /// transient, so the write is rethrown to the user rather than buried in
    /// the retry queue.
    @Test("a Postgrest server rejection is NOT transient → rethrown, never queued")
    func serverRejectionIsNotTransient() {
        #expect(!isTransient(PostgrestError(message: "new row violates row-level security policy")))
    }

    @Test("a plain Swift error is NOT transient")
    func plainErrorIsNotTransient() {
        struct Boom: Error {}
        #expect(!isTransient(Boom()))
    }

    /// An NSError in a non-URL domain (e.g. a decoding/Cocoa error) is a real
    /// failure, not connectivity — it must not be queued either.
    @Test("an NSError in a non-URL domain is NOT transient")
    func nonURLDomainNSErrorIsNotTransient() {
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: 4864)
        #expect(!isTransient(cocoaError))
    }
}
