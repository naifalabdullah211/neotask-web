"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  nextRateLimitState,
  normalizeEmployeeNumber,
  rateLimitDocumentId,
  requirePlainText,
  secretsEqual,
} = require("../security");

test("fixed-window rate limit blocks the first request above the limit", () => {
  const config = {limit: 2, windowMs: 60_000};
  const first = nextRateLimitState(null, 1_000, config);
  const second = nextRateLimitState(first, 2_000, config);
  const blocked = nextRateLimitState(second, 3_000, config);

  assert.equal(first.allowed, true);
  assert.equal(second.allowed, true);
  assert.deepEqual(blocked, {
    allowed: false,
    count: 2,
    resetAtMs: 61_000,
  });
});

test("fixed-window rate limit resets after the window expires", () => {
  const reset = nextRateLimitState(
      {count: 9, resetAtMs: 10_000},
      10_000,
      {limit: 2, windowMs: 60_000},
  );
  assert.deepEqual(reset, {allowed: true, count: 1, resetAtMs: 70_000});
});

test("rate-limit identifiers are hashed before persistence", () => {
  const id = rateLimitDocumentId("bootstrap", "203.0.113.10");
  assert.match(id, /^bootstrap_[a-f0-9]{64}$/);
  assert.equal(id.includes("203.0.113.10"), false);
});

test("plain-text validation rejects control characters without altering text", () => {
  assert.equal(requirePlainText("  مهمة الجودة  ", "title"), "مهمة الجودة");
  assert.throws(() => requirePlainText("safe\u0000hidden", "title"), TypeError);
});

test("employee numbers are bounded and normalized server-side", () => {
  assert.deepEqual(normalizeEmployeeNumber(" RC-400161 "), {
    display: "RC-400161",
    compact: "rc400161",
  });
  assert.throws(() => normalizeEmployeeNumber("<script>"), TypeError);
});

test("secret comparison accepts only an exact value", () => {
  assert.equal(secretsEqual("correct-value", "correct-value"), true);
  assert.equal(secretsEqual("correct-value ", "correct-value"), false);
  assert.equal(secretsEqual(null, "correct-value"), false);
});

test("every sensitive callable keeps its server-side rate-limit gate", () => {
  const source = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  assert.match(
      source,
      /exports\.adminResetPassword[\s\S]*?requireRateLimit\(request, "admin_reset_password"/,
  );
  assert.match(
      source,
      /exports\.bulkImportEmployees[\s\S]*?requireRateLimit\(request, "bulk_import_employees"/,
  );
});

test("Spark manager bootstrap consumes a hidden proof atomically", () => {
  const rules = fs.readFileSync(
      path.join(__dirname, "..", "..", "firestore.rules"),
      "utf8",
  );
  assert.match(rules, /match \/system\/manager_bootstrap/);
  assert.match(rules, /allow read, create, update: if false/);
  assert.match(rules, /!existsAfter\([\s\S]*?system\/manager_bootstrap/);
  assert.match(rules, /afterUser\.bootstrapProof == managerBootstrap\(\)\.proofHash/);
  assert.match(rules, /afterLock\.createdBy == uid/);
});

test("production deploy stays on Spark and never deploys paid functions", () => {
  const workflow = fs.readFileSync(
      path.join(
          __dirname,
          "..",
          "..",
          ".github",
          "workflows",
          "deploy-firebase-hosting.yml",
      ),
      "utf8",
  );
  assert.doesNotMatch(workflow, /firebase deploy --only functions/);
  assert.doesNotMatch(workflow, /secretmanager\.googleapis\.com/);
  assert.match(workflow, /One-time manager setup proof provisioned/);
});
