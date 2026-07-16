// Pure recipient-resolution helper for notify-message (see index.ts), split
// out so the "who gets notified" rule is unit-testable without a live DB
// (see recipient.test.ts, `deno test`).
//
// An engagement has exactly two parties. The recipient of a message is
// whichever party did NOT author it.

export interface EngagementParties {
  client_id: string;
  professional_id: string;
}

export function recipientOf(engagement: EngagementParties, authorId: string): string {
  return authorId === engagement.client_id ? engagement.professional_id : engagement.client_id;
}
