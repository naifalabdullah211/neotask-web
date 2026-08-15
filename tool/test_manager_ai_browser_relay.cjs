const admin = require('firebase-admin');
const fs = require('node:fs');
const { chromium } = require('playwright');

const projectId = 'neotask1-ff5a4';
const apiKey = 'AIzaSyAH4nvOmEuBXlYmSgTvVedEyGGqcVhXcZ4';
const site = 'https://neotask1-ff5a4.web.app';
const relayOrigin = 'https://neotask-agent-bridge-xo992u.v2.appdeploy.ai';
const relayUrl = `${relayOrigin}/?relay=1`;

async function managerIdToken() {
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialsPath) throw new Error('missing-service-account');
  const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId });
  const db = admin.firestore();
  const users = await db.collection('users').get();
  let uid = '';
  for (const doc of users.docs) {
    const data = doc.data();
    const number = String(data.employeeNumber || '').replace(/\D/g, '');
    if (data.accountStatus === 'active' && (data.role === 'manager' || number === '400161')) {
      uid = doc.id;
      break;
    }
  }
  if (!uid) throw new Error('manager-not-found');
  const customToken = await admin.auth().createCustomToken(uid, { neoTaskManager: true });
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  });
  const body = await response.json();
  if (!response.ok || !body.idToken) throw new Error(`firebase-token-${response.status}`);
  return body.idToken;
}

async function main() {
  const idToken = await managerIdToken();
  const liveJs = await fetch(`${site}/main.dart.js`, { cache: 'no-store' });
  const js = liveJs.ok ? await liveJs.text() : '';
  const deployedRelayCode = js.includes(relayOrigin) && js.includes('neotask-ai-request');

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(`${site}/?aiRelaySmoke=1`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    const started = Date.now();
    const result = await page.evaluate(async ({ relayOrigin, relayUrl, idToken }) => {
      return await new Promise((resolve, reject) => {
        const id = `smoke-${Date.now()}-${Math.random().toString(16).slice(2)}`;
        const timeout = setTimeout(() => {
          cleanup();
          reject(new Error('relay-timeout'));
        }, 90000);
        const iframe = document.createElement('iframe');
        iframe.src = relayUrl;
        iframe.style.position = 'fixed';
        iframe.style.width = '1px';
        iframe.style.height = '1px';
        iframe.style.left = '-10000px';
        iframe.style.top = '-10000px';
        iframe.style.opacity = '0';
        iframe.setAttribute('aria-hidden', 'true');
        function cleanup() {
          clearTimeout(timeout);
          window.removeEventListener('message', onMessage);
          iframe.remove();
        }
        function onMessage(event) {
          if (event.origin !== relayOrigin || typeof event.data !== 'string') return;
          let message;
          try { message = JSON.parse(event.data); } catch { return; }
          if (message.channel !== 'neotask-ai-response' || message.id !== id) return;
          cleanup();
          resolve(message);
        }
        window.addEventListener('message', onMessage);
        iframe.onload = () => {
          iframe.contentWindow.postMessage(JSON.stringify({
            channel: 'neotask-ai-request',
            id,
            method: 'POST',
            languageCode: 'en',
            firebaseToken: idToken,
            body: {
              message: 'Hi',
              history: [],
              teamContext: [],
              taskContext: [],
              projectContext: [],
              meetingContext: [],
              knowledgeContext: [],
              qualityContext: {},
              agentRules: [],
              truthMode: true,
              languageCode: 'en',
            },
          }), relayOrigin);
        };
        document.body.appendChild(iframe);
      });
    }, { relayOrigin, relayUrl, idToken });

    const data = result && result.data && typeof result.data === 'object' ? result.data : {};
    const safe = {
      ok: result?.ok === true,
      deployedRelayCode,
      elapsedMs: Date.now() - started,
      status: result?.status || 200,
      mode: data.mode || null,
      replyLength: typeof data.reply === 'string' ? data.reply.length : 0,
      delegatedAgentCount: Array.isArray(data.delegatedAgents) ? data.delegatedAgents.length : 0,
    };
    console.log(JSON.stringify(safe));
    if (!safe.ok || !safe.deployedRelayCode || safe.replyLength < 2 || safe.delegatedAgentCount < 1) {
      process.exitCode = 1;
    }
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.log(JSON.stringify({ ok: false, stage: 'browser-relay-fatal', error: error.message }));
  process.exitCode = 1;
});
