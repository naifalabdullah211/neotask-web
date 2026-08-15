const admin = require('firebase-admin');
const fs = require('node:fs');

const projectId = 'neotask1-ff5a4';
const apiKey = 'AIzaSyAH4nvOmEuBXlYmSgTvVedEyGGqcVhXcZ4';
const endpoint = 'https://neotask-ai.rcmc.workers.dev/api/multi-agent';
const origin = 'https://neotask1-ff5a4.web.app';

async function main() {
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialsPath) throw new Error('missing-service-account');
  const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  admin.initializeApp({credential: admin.credential.cert(serviceAccount), projectId});

  const db = admin.firestore();
  const users = await db.collection('users').get();
  let manager = null;
  for (const doc of users.docs) {
    const data = doc.data();
    const employeeNumber = String(data.employeeNumber || '').replace(/\D/g, '');
    if (data.accountStatus === 'active' && (data.role === 'manager' || employeeNumber === '400161')) {
      manager = {uid: doc.id};
      break;
    }
  }
  if (!manager) throw new Error('manager-not-found');

  const customToken = await admin.auth().createCustomToken(manager.uid, {neoTaskManager: true});
  const signInResponse = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({token: customToken, returnSecureToken: true}),
  });
  const signInBody = await signInResponse.json();
  if (!signInResponse.ok || !signInBody.idToken) {
    throw new Error(`firebase-signin-${signInResponse.status}-${signInBody.error?.message || 'unknown'}`);
  }

  const healthResponse = await fetch(`${endpoint}?lang=en`, {
    headers: {Origin: origin},
    signal: AbortSignal.timeout(20000),
  });
  const health = await healthResponse.json().catch(() => ({}));
  if (!healthResponse.ok || health.status !== 'ready' || health.count !== 8 || health.provider !== 'cloudflare-workers-ai') {
    console.log(JSON.stringify({stage:'health',ok:false,status:healthResponse.status,error:health.error||null,provider:health.provider||null,count:health.count||0}));
    process.exitCode = 1;
    return;
  }

  const started = Date.now();
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${signInBody.idToken}`,
      'Content-Type': 'application/json',
      Origin: origin,
    },
    body: JSON.stringify({message:'Hi',history:[],teamContext:[],taskContext:[],projectContext:[],meetingContext:[],knowledgeContext:[],qualityContext:{},agentRules:[],truthMode:true,languageCode:'en'}),
    signal: AbortSignal.timeout(90000),
  });
  const text = await response.text();
  let body = {};
  try { body = JSON.parse(text); } catch {}
  const safe = {
    stage: 'cloudflare-manager-ai-post',
    ok: response.ok,
    status: response.status,
    elapsedMs: Date.now() - started,
    error: body.error || null,
    provider: body.provider || null,
    model: body.model || null,
    mode: body.mode || null,
    delegatedAgentCount: Array.isArray(body.delegatedAgents) ? body.delegatedAgents.length : 0,
    replyLength: typeof body.reply === 'string' ? body.reply.length : 0,
    corsOrigin: response.headers.get('access-control-allow-origin'),
  };
  console.log(JSON.stringify(safe));
  const valid = response.ok && body.provider === 'cloudflare-workers-ai' && body.mode === 'multi-agent' && safe.replyLength > 2 && safe.delegatedAgentCount >= 2 && safe.corsOrigin === origin;
  if (!valid) process.exitCode = 1;
}

main().catch((error) => {
  console.log(JSON.stringify({stage:'fatal',ok:false,error:error.message}));
  process.exitCode = 1;
});
