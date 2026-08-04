"use strict";

const crypto = require("crypto");

const CONTROL_CHARACTERS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;

function requirePlainText(value, fieldName, {minLength = 1, maxLength = 160} = {}) {
  if (typeof value !== "string") {
    throw new TypeError(`${fieldName} must be a string`);
  }
  const normalized = value.trim();
  if (normalized.length < minLength || normalized.length > maxLength) {
    throw new RangeError(`${fieldName} has an invalid length`);
  }
  if (CONTROL_CHARACTERS.test(normalized)) {
    throw new TypeError(`${fieldName} contains control characters`);
  }
  return normalized;
}

function normalizeEmployeeNumber(value) {
  const normalized = requirePlainText(value, "employeeNumber", {
    minLength: 1,
    maxLength: 32,
  });
  if (!/^[a-zA-Z0-9_-]+$/.test(normalized)) {
    throw new TypeError("employeeNumber contains unsupported characters");
  }
  const compact = normalized.toLowerCase().replace(/[^a-z0-9]/g, "");
  if (!compact) {
    throw new TypeError("employeeNumber is empty after normalization");
  }
  return {display: normalized, compact};
}

function secretsEqual(provided, expected) {
  if (typeof provided !== "string" || typeof expected !== "string") {
    return false;
  }
  const providedDigest = crypto.createHash("sha256").update(provided).digest();
  const expectedDigest = crypto.createHash("sha256").update(expected).digest();
  return crypto.timingSafeEqual(providedDigest, expectedDigest);
}

function rateLimitDocumentId(scope, identifier) {
  const digest = crypto.createHash("sha256")
      .update(`${scope}:${identifier}`)
      .digest("hex");
  return `${scope}_${digest}`;
}

function nextRateLimitState(existing, nowMs, {limit, windowMs}) {
  if (!Number.isInteger(limit) || limit < 1 ||
      !Number.isInteger(windowMs) || windowMs < 1) {
    throw new TypeError("Invalid rate-limit configuration");
  }
  const resetAtMs = existing && Number(existing.resetAtMs);
  const currentCount = existing && Number(existing.count);
  const stillOpen = Number.isFinite(resetAtMs) && resetAtMs > nowMs;
  const count = stillOpen && Number.isFinite(currentCount) ? currentCount : 0;
  if (count >= limit) {
    return {allowed: false, count, resetAtMs};
  }
  return {
    allowed: true,
    count: count + 1,
    resetAtMs: stillOpen ? resetAtMs : nowMs + windowMs,
  };
}

async function enforceRateLimit({
  db,
  scope,
  identifier,
  limit,
  windowMs,
  nowMs = Date.now(),
}) {
  const ref = db.collection("_security_rate_limits")
      .doc(rateLimitDocumentId(scope, identifier));
  const state = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const next = nextRateLimitState(
        snapshot.exists ? snapshot.data() : null,
        nowMs,
        {limit, windowMs},
    );
    if (next.allowed) {
      transaction.set(ref, {
        scope,
        count: next.count,
        resetAtMs: next.resetAtMs,
        expiresAt: new Date(next.resetAtMs + windowMs),
      });
    }
    return next;
  });
  return state;
}

module.exports = {
  enforceRateLimit,
  nextRateLimitState,
  normalizeEmployeeNumber,
  rateLimitDocumentId,
  requirePlainText,
  secretsEqual,
};
