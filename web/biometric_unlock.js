(function installNeoTaskBiometrics(global) {
  'use strict';

  const RECORD_PREFIX = 'neotask.biometric.v1.';
  const OFFER_PREFIX = 'neotask.biometric.offer.v1.';
  const INTERACTIVE_LOGIN_PREFIX = 'neotask.interactive-login.v1.';
  const encoder = new TextEncoder();

  function requireUid(uid) {
    const value = String(uid || '').trim();
    if (!value || value.length > 128) {
      throw new Error('biometric-invalid-user');
    }
    return value;
  }

  function recordKey(uid) {
    return `${RECORD_PREFIX}${requireUid(uid)}`;
  }

  function offerKey(uid) {
    return `${OFFER_PREFIX}${requireUid(uid)}`;
  }

  function interactiveLoginKey(uid) {
    return `${INTERACTIVE_LOGIN_PREFIX}${requireUid(uid)}`;
  }

  function encodeBase64Url(value) {
    const bytes = new Uint8Array(value);
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/g, '');
  }

  function decodeBase64Url(value) {
    const normalized = String(value || '').replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  }

  function randomChallenge() {
    const value = new Uint8Array(32);
    global.crypto.getRandomValues(value);
    return value;
  }

  function readRecord(uid) {
    try {
      const raw = global.localStorage.getItem(recordKey(uid));
      if (!raw) return null;
      const record = JSON.parse(raw);
      if (
        !record ||
        typeof record.credentialId !== 'string' ||
        !record.credentialId ||
        record.rpId !== global.location.hostname ||
        typeof record.userHandle !== 'string' ||
        !record.userHandle
      ) {
        return null;
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  function writeRecord(uid, record) {
    try {
      global.localStorage.setItem(recordKey(uid), JSON.stringify(record));
    } catch (_) {
      throw new Error('biometric-storage-unavailable');
    }
  }

  function deleteRecord(uid) {
    try {
      global.localStorage.removeItem(recordKey(uid));
    } catch (_) {
      throw new Error('biometric-storage-unavailable');
    }
  }

  function setOfferDismissed(uid, dismissed) {
    try {
      if (dismissed) {
        global.localStorage.setItem(offerKey(uid), '1');
      } else {
        global.localStorage.removeItem(offerKey(uid));
      }
    } catch (_) {
      // The offer is optional. Storage failure must not block sign-in.
    }
  }

  function isOfferDismissed(uid) {
    try {
      return global.localStorage.getItem(offerKey(uid)) === '1';
    } catch (_) {
      return true;
    }
  }

  function mapCredentialError(error) {
    if (error && error.message && String(error.message).startsWith('biometric-')) {
      return error;
    }
    const name = error && error.name ? String(error.name) : '';
    if (name === 'NotAllowedError' || name === 'AbortError') {
      return new Error('biometric-cancelled');
    }
    if (name === 'InvalidStateError') {
      return new Error('biometric-already-enrolled');
    }
    if (name === 'SecurityError') {
      return new Error('biometric-origin-invalid');
    }
    return new Error('biometric-failed');
  }

  function hasWebAuthnPrimitives() {
    return Boolean(
      global.isSecureContext &&
        global.PublicKeyCredential &&
        global.navigator &&
        global.navigator.credentials &&
        typeof global.navigator.credentials.create === 'function' &&
        typeof global.navigator.credentials.get === 'function' &&
        global.crypto &&
        typeof global.crypto.getRandomValues === 'function'
    );
  }

  async function isSupported() {
    if (!hasWebAuthnPrimitives()) return false;
    const capability = global.PublicKeyCredential
      .isUserVerifyingPlatformAuthenticatorAvailable;
    if (typeof capability !== 'function') return true;
    try {
      return Boolean(await capability.call(global.PublicKeyCredential));
    } catch (_) {
      return false;
    }
  }

  async function assertExistingCredential(uid, record) {
    let credential;
    try {
      credential = await global.navigator.credentials.get({
        publicKey: {
          challenge: randomChallenge(),
          rpId: record.rpId,
          allowCredentials: [
            {
              id: decodeBase64Url(record.credentialId),
              type: 'public-key',
              transports: ['internal'],
            },
          ],
          userVerification: 'required',
          timeout: 60000,
        },
      });
    } catch (error) {
      throw mapCredentialError(error);
    }

    if (
      !credential ||
      credential.type !== 'public-key' ||
      encodeBase64Url(credential.rawId) !== record.credentialId
    ) {
      throw new Error('biometric-credential-mismatch');
    }

    const returnedHandle = credential.response && credential.response.userHandle;
    if (returnedHandle && encodeBase64Url(returnedHandle) !== record.userHandle) {
      throw new Error('biometric-user-mismatch');
    }
    return credential;
  }

  async function enroll(uid, userName, displayName) {
    const normalizedUid = requireUid(uid);
    // Do not await a capability probe here. Safari ties WebAuthn to the
    // original button activation, so credentials.create() must be reached
    // synchronously from the user's click.
    if (!hasWebAuthnPrimitives()) throw new Error('biometric-unsupported');

    const existing = readRecord(normalizedUid);
    if (existing) {
      await assertExistingCredential(normalizedUid, existing);
      writeRecord(normalizedUid, {
        ...existing,
        enabled: true,
        lastUnlockedAt: new Date().toISOString(),
      });
      setOfferDismissed(normalizedUid, false);
      return true;
    }

    const userId = encoder.encode(normalizedUid);
    if (userId.byteLength > 64) throw new Error('biometric-invalid-user');

    let credential;
    try {
      credential = await global.navigator.credentials.create({
        publicKey: {
          challenge: randomChallenge(),
          rp: {
            id: global.location.hostname,
            name: 'NeoTask',
          },
          user: {
            id: userId,
            name: String(userName || normalizedUid).slice(0, 120),
            displayName: String(displayName || userName || 'NeoTask user').slice(0, 120),
          },
          pubKeyCredParams: [
            { type: 'public-key', alg: -7 },
            { type: 'public-key', alg: -257 },
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            residentKey: 'required',
            requireResidentKey: true,
            userVerification: 'required',
          },
          attestation: 'none',
          timeout: 60000,
        },
      });
    } catch (error) {
      throw mapCredentialError(error);
    }

    if (!credential || credential.type !== 'public-key' || !credential.rawId) {
      throw new Error('biometric-failed');
    }

    writeRecord(normalizedUid, {
      version: 1,
      credentialId: encodeBase64Url(credential.rawId),
      userHandle: encodeBase64Url(userId),
      rpId: global.location.hostname,
      enabled: true,
      enabledAt: new Date().toISOString(),
      lastUnlockedAt: new Date().toISOString(),
    });
    setOfferDismissed(normalizedUid, false);
    return true;
  }

  async function unlock(uid) {
    const normalizedUid = requireUid(uid);
    const record = readRecord(normalizedUid);
    if (!record || record.enabled === false) {
      throw new Error('biometric-not-enrolled');
    }
    // Keep credentials.get() in the original user-activation chain.
    if (!hasWebAuthnPrimitives()) throw new Error('biometric-unsupported');

    await assertExistingCredential(normalizedUid, record);
    writeRecord(normalizedUid, {
      ...record,
      lastUnlockedAt: new Date().toISOString(),
    });
    return true;
  }

  async function isEnabled(uid) {
    const record = readRecord(uid);
    return Boolean(record && record.enabled !== false);
  }

  async function shouldOfferEnrollment(uid) {
    if (!(await isSupported())) return false;
    return !readRecord(uid) && !isOfferDismissed(uid);
  }

  async function dismissEnrollmentOffer(uid) {
    setOfferDismissed(uid, true);
    return true;
  }

  async function disable(uid) {
    const normalizedUid = requireUid(uid);
    // Forget the local credential link rather than retaining a disabled,
    // possibly stale id. A later explicit enable can then create a fresh
    // platform credential if the old passkey was deleted or became invalid.
    deleteRecord(normalizedUid);
    setOfferDismissed(normalizedUid, true);
    return true;
  }

  async function markInteractiveLogin(uid) {
    try {
      global.sessionStorage.setItem(interactiveLoginKey(uid), '1');
    } catch (_) {
      // This marker is only a one-navigation UX optimization.
    }
    return true;
  }

  async function consumeInteractiveLogin(uid) {
    try {
      const key = interactiveLoginKey(uid);
      const marked = global.sessionStorage.getItem(key) === '1';
      global.sessionStorage.removeItem(key);
      return marked;
    } catch (_) {
      return false;
    }
  }

  global.neoTaskBiometrics = Object.freeze({
    isSupported,
    isEnabled,
    shouldOfferEnrollment,
    dismissEnrollmentOffer,
    enroll,
    unlock,
    disable,
    markInteractiveLogin,
    consumeInteractiveLogin,
  });
})(window);
