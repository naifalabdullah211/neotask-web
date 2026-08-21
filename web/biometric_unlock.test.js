import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const bridgeSource = readFileSync(
  new URL('./biometric_unlock.js', import.meta.url),
  'utf8',
);

function createStorage() {
  const values = new Map();
  return {
    getItem(key) {
      return values.has(String(key)) ? values.get(String(key)) : null;
    },
    setItem(key, value) {
      values.set(String(key), String(value));
    },
    removeItem(key) {
      values.delete(String(key));
    },
    snapshot() {
      return Object.fromEntries(values);
    },
  };
}

function createHarness({
  hostname = 'neotask.example',
  secureContext = true,
  platformAuthenticatorAvailable = true,
} = {}) {
  const localStorage = createStorage();
  const sessionStorage = createStorage();
  const calls = { create: [], get: [], platformCapability: 0 };
  const rawId = Uint8Array.from([9, 7, 5, 3, 1]).buffer;
  let getResultFactory = () => ({
    type: 'public-key',
    rawId,
    response: { userHandle: null },
  });

  const credentials = {
    async create(options) {
      calls.create.push(options);
      return { type: 'public-key', rawId, response: {} };
    },
    async get(options) {
      calls.get.push(options);
      return getResultFactory();
    },
  };

  const window = {
    isSecureContext: secureContext,
    location: { hostname },
    localStorage,
    sessionStorage,
    navigator: { credentials },
    crypto: {
      getRandomValues(value) {
        for (let index = 0; index < value.length; index += 1) {
          value[index] = (index * 17 + 11) % 256;
        }
        return value;
      },
    },
    PublicKeyCredential: {
      async isUserVerifyingPlatformAuthenticatorAvailable() {
        calls.platformCapability += 1;
        return platformAuthenticatorAvailable;
      },
    },
  };

  const context = {
    window,
    TextEncoder,
    Uint8Array,
    Date,
    JSON,
    Object,
    String,
    Boolean,
    Error,
    btoa(value) {
      return Buffer.from(value, 'binary').toString('base64');
    },
    atob(value) {
      return Buffer.from(value, 'base64').toString('binary');
    },
  };

  vm.runInNewContext(bridgeSource, context, {
    filename: 'web/biometric_unlock.js',
  });

  return {
    api: window.neoTaskBiometrics,
    calls,
    localStorage,
    sessionStorage,
    setGetResult(factory) {
      getResultFactory = factory;
    },
  };
}

test('support requires a secure context and a platform authenticator', async () => {
  const insecure = createHarness({ secureContext: false });
  assert.equal(await insecure.api.isSupported(), false);

  const unavailable = createHarness({
    platformAuthenticatorAvailable: false,
  });
  assert.equal(await unavailable.api.isSupported(), false);

  const supported = createHarness();
  assert.equal(await supported.api.isSupported(), true);
});

test('gesture-bound enrollment and unlock skip the async capability probe', async () => {
  const harness = createHarness();
  const uid = 'firebase-user-a';

  await harness.api.enroll(uid, 'EMP-001', 'Employee A');
  assert.equal(harness.calls.create.length, 1);
  assert.equal(harness.calls.platformCapability, 0);

  await harness.api.unlock(uid);
  assert.equal(harness.calls.get.length, 1);
  assert.equal(harness.calls.platformCapability, 0);
});

test('enrollment requires platform verification and stays isolated per uid', async () => {
  const harness = createHarness();
  const uid = 'firebase-user-a';

  assert.equal(await harness.api.shouldOfferEnrollment(uid), true);
  await harness.api.enroll(uid, 'EMP-001', 'موظف تجريبي');

  assert.equal(harness.calls.create.length, 1);
  const options = harness.calls.create[0].publicKey;
  assert.equal(options.rp.id, 'neotask.example');
  assert.equal(options.rp.name, 'NeoTask');
  assert.equal(options.challenge.byteLength, 32);
  assert.equal(
    options.authenticatorSelection.authenticatorAttachment,
    'platform',
  );
  assert.equal(options.authenticatorSelection.residentKey, 'required');
  assert.equal(options.authenticatorSelection.userVerification, 'required');
  assert.equal(options.attestation, 'none');

  assert.equal(await harness.api.isEnabled(uid), true);
  assert.equal(await harness.api.isEnabled('firebase-user-b'), false);

  const stored = harness.localStorage.snapshot();
  const recordKey = `neotask.biometric.v1.${uid}`;
  assert.deepEqual(Object.keys(stored), [recordKey]);
  const record = JSON.parse(stored[recordKey]);
  assert.equal(record.rpId, 'neotask.example');
  assert.equal(record.enabled, true);
  assert.equal(typeof record.credentialId, 'string');
  assert.equal(typeof record.userHandle, 'string');

  const serializedRecord = stored[recordKey];
  assert.doesNotMatch(serializedRecord, /EMP-001|موظف تجريبي|password/i);
  await assert.rejects(
    harness.api.enroll('x'.repeat(65), 'EMP-002', 'Long uid'),
    /biometric-invalid-user/,
  );
});

test('unlock verifies the enrolled credential and disabling is persistent', async () => {
  const harness = createHarness();
  const uid = 'firebase-user-a';
  await harness.api.enroll(uid, 'EMP-001', 'Employee A');

  await harness.api.unlock(uid);
  assert.equal(harness.calls.get.length, 1);
  const options = harness.calls.get[0].publicKey;
  assert.equal(options.rpId, 'neotask.example');
  assert.equal(options.userVerification, 'required');
  assert.equal(options.challenge.byteLength, 32);
  assert.equal(options.allowCredentials.length, 1);
  assert.equal(options.allowCredentials[0].type, 'public-key');
  assert.deepEqual(
    Array.from(options.allowCredentials[0].transports),
    ['internal'],
  );

  harness.setGetResult(() => ({
    type: 'public-key',
    rawId: Uint8Array.from([1, 2, 3]).buffer,
    response: { userHandle: null },
  }));
  await assert.rejects(
    harness.api.unlock(uid),
    /biometric-credential-mismatch/,
  );

  await harness.api.disable(uid);
  assert.equal(await harness.api.isEnabled(uid), false);
  assert.equal(await harness.api.shouldOfferEnrollment(uid), false);
  await assert.rejects(
    harness.api.unlock(uid),
    /biometric-not-enrolled/,
  );

  await harness.api.enroll(uid, 'EMP-001', 'Employee A');
  assert.equal(harness.calls.create.length, 2);
  assert.equal(await harness.api.isEnabled(uid), true);
});

test('offer dismissal and interactive-login markers are scoped and one-shot', async () => {
  const harness = createHarness();
  const uid = 'firebase-user-a';
  const otherUid = 'firebase-user-b';

  assert.equal(await harness.api.shouldOfferEnrollment(uid), true);
  await harness.api.dismissEnrollmentOffer(uid);
  assert.equal(await harness.api.shouldOfferEnrollment(uid), false);
  assert.equal(await harness.api.shouldOfferEnrollment(otherUid), true);
  assert.deepEqual(harness.localStorage.snapshot(), {
    [`neotask.biometric.offer.v1.${uid}`]: '1',
  });

  assert.equal(await harness.api.consumeInteractiveLogin(uid), false);
  await harness.api.markInteractiveLogin(uid);
  assert.deepEqual(harness.sessionStorage.snapshot(), {
    [`neotask.interactive-login.v1.${uid}`]: '1',
  });
  assert.equal(await harness.api.consumeInteractiveLogin(otherUid), false);
  assert.equal(await harness.api.consumeInteractiveLogin(uid), true);
  assert.equal(await harness.api.consumeInteractiveLogin(uid), false);
  assert.deepEqual(harness.sessionStorage.snapshot(), {});
});
