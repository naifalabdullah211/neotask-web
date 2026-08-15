const admin = require('firebase-admin');
const fs = require('node:fs');
const { chromium } = require('playwright');

const projectId = 'neotask1-ff5a4';
const apiKey = 'AIzaSyAH4nvOmEuBXlYmSgTvVedEyGGqcVhXcZ4';
const site = 'https://neotask1-ff5a4.web.app';
const endpoint = 'https://neotask-ai.rcmc.workers.dev/api/multi-agent';

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
  const deployedCloudflareCode = js.includes('neotask-ai.rcmc.workers.dev') && !js.includes('neotask-agent-bridge-xo992u.v2.appdeploy.ai');

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(`${site}/?aiCloudflareSmoke=1`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    const started = Date.now();
    const result = await page.evaluate(async ({ endpoint, idToken }) => {
      const healthResponse = await fetch(`${endpoint}?lang=en`, { cache: 'no-store' });
      const health = await healthResponse.json();
      if (!healthResponse.ok || health.status !== 'ready' || health.count !== 8) {
        return {ok:false, stage:'health', status:healthResponse.status, health};
      }
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${idToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
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
        }),
      });
      const body = await response.json().catch(() => ({}));
      return {
        ok: response.ok,
        status: response.status,
        provider: body.provider || null,
        model: body.model || null,
        mode: body.mode || null,
        error: body.error || null,
        replyLength: typeof body.reply === 'string' ? body.reply.length : 0,
        delegatedAgentCount: Array.isArray(body.delegatedAgents) ? body.delegatedAgents.length : 0,
      };
    }, { endpoint, idToken });

    const safe = {
      ...result,
      deployedCloudflareCode,
      elapsedMs: Date.now() - started,
    };
    console.log(JSON.stringify(safe));
    const valid = safe.ok === true && safe.deployedCloudflareCode && safe.status === 200 && safe.provider === 'cloudflare-workers-ai' && safe.mode === 'multi-agent' && safe.replyLength > 2 && safe.delegatedAgentCount >= 2;
    if (!valid) process.exitCode = 1;
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.log(JSON.stringify({ ok: false, stage: 'browser-cloudflare-fatal', error: error.message }));
  process.exitCode = 1;
});
