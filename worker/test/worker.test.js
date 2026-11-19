import assert from "node:assert/strict";
import test from "node:test";
import { isRateLimited, validateMessages } from "../src/index.js";

test("accepts a user conversation with assistant history", () => {
  const messages = validateMessages([
    { role: "user", text: "¿Cómo repartimos la cuenta?" },
    { role: "model", text: "Puedo ayudarte." },
    { role: "user", text: "Somos tres." },
  ]);

  assert.deepEqual(messages, [
    { role: "user", content: "¿Cómo repartimos la cuenta?" },
    { role: "model", content: "Puedo ayudarte." },
    { role: "user", content: "Somos tres." },
  ]);
});

test("rejects malformed or oversized conversation history", () => {
  assert.throws(() => validateMessages([]));
  assert.throws(() =>
    validateMessages([{ role: "user", text: "hola" }, { role: "bad", text: "x" }]),
  );
  assert.throws(() =>
    validateMessages([{ role: "user", text: "x".repeat(2001) }]),
  );
  assert.throws(() =>
    validateMessages([
      { role: "user", text: "hola" },
      { role: "model", text: "respuesta" },
    ]),
  );
});

test("rate limits each user within the worker instance", () => {
  const userId = `test-${crypto.randomUUID()}`;
  for (let request = 0; request < 12; request += 1) {
    assert.equal(isRateLimited(userId), false);
  }
  assert.equal(isRateLimited(userId), true);
});

test("handles preflight requests without requiring a login token", async () => {
  const response = await (await import("../src/index.js")).default.fetch(
    new Request("https://assistant.test", {
      method: "OPTIONS",
      headers: { Origin: "https://example.test" },
    }),
    {},
  );

  assert.equal(response.status, 204);
  assert.equal(
    response.headers.get("Access-Control-Allow-Origin"),
    "https://example.test",
  );
});
