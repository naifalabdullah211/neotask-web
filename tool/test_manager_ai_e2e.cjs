const admin = require('firebase-admin');
const fs = require('node:fs');

const projectId = 'neotask1-ff5a4';
const apiKey = 'AIzaSyAH4nvOmEuBXlYmSgTvVedEyGGqcVhXcZ4';
const baseUrl = 'https://neotask-agent-bridge-xo992u.v2.appdeploy.ai/';
const endpoint = `${baseUrl}api/multi-agent`;

async function main() {
  const root = await fetch(baseUrl, {redirect: 'manual'});
  console.log(JSON.stringify({
    stage: 'frame-headers',
    status: root.status,
    xFrameOptions: root.headers.get('x-frame-options'),
    csp: root.headers.get('content-security-policy'),
  }));

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

  const started = Date.now();
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${signInBody.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({message:'Hi',history:[],teamContext:[],taskContext:[],projectContext:[],meetingContext:[],knowledgeContext:[],qualityContext:{},agentRules:[],truthMode:true,languageCode:'en'}),
    signal: AbortSignal.timeout(90000),
  });
  const text = await response.text();
  let body = {};
  try { body = JSON.parse(text); } catch {}
  console.log(JSON.stringify({
    stage: 'production-ai-post-server-to-server',
    ok: response.ok,
    status: response.status,
    elapsedMs: Date.now() - started,
    error: body.error || null,
    mode: body.mode || null,
    delegatedAgentCount: Array.isArray(body.delegatedAgents) ? body.delegatedAgents.length : 0,
    replyLength: typeof body.reply === 'string' ? body.reply.length : 0,
  }));
  if (!response.ok) process.exitCode = 1;
}

main().catch((error) => {
  console.log(JSON.stringify({stage: 'fatal', ok: false, error: error.message}));
  process.exitCode = 1;
});
