// Pure unit tests for recipient.ts's recipient-resolution rule — no DB, no
// Docker, just `deno test` (see recipient.ts's header comment).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { recipientOf } from "./recipient.ts";

Deno.test("author is the client -> recipient is the professional", () => {
  const engagement = { client_id: "client-1", professional_id: "pro-1" };
  assertEquals(recipientOf(engagement, "client-1"), "pro-1");
});

Deno.test("author is the professional -> recipient is the client", () => {
  const engagement = { client_id: "client-1", professional_id: "pro-1" };
  assertEquals(recipientOf(engagement, "pro-1"), "client-1");
});
