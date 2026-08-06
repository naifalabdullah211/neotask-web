import crypto from 'node:crypto';

const FIREBASE_PROJECT_ID = 'neotask1-ff5a4';
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-5.4-mini';
const ALLOWED_ORIGINS = new Set([
  'https://neotask1-ff5a4.web.app',
  'https://neotask1-ff5a4.firebaseapp.com',
  'http://localhost:5000',
  'http://localhost:3000',
]);
const requestWindows = new Map();

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type');
  res.setHeader('Cache-Control', 'no-store');
}

function json(res, status, body) {
  res.status(status).json(body);
}

function bearerToken(req) {
  const value = req.headers.authorization || '';
  return value.startsWith('Bearer ') ? value.slice(7).trim() : '';
}

function decodeFirebaseIdentity(token) {
  if (!token) throw new Error('missing-token');
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('invalid-token');

  let claims;
  try {
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw new Error('invalid-token');
  }

  const issuer = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
  const now = Math.floor(Date.now() / 1000);
  if (
    claims.aud !== FIREBASE_PROJECT_ID ||
    claims.iss !== issuer ||
    !claims.sub ||
    typeof claims.exp !== 'number' ||
    claims.exp <= now
  ) {
    throw new Error('invalid-token');
  }

  return {uid: claims.sub, email: claims.email || ''};
}

async function loadNeoTaskUser(token, uid) {
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
  const response = await fetch(url, {
    headers: {Authorization: `Bearer ${token}`, 'Cache-Control': 'no-store'},
  });

  if (response.status === 401 || response.status === 403) {
    throw new Error('invalid-token');
  }
  if (!response.ok) throw new Error('profile-unavailable');

  const document = await response.json();
  const fields = document.fields || {};
  const stringValue = (name) => fields[name]?.stringValue || '';
  return {
    uid,
    name: stringValue('name'),
    role: stringValue('role'),
    employeeNumber: stringValue('employeeNumber'),
    accountStatus: stringValue('accountStatus'),
  };
}

function enforceManager(user) {
  const normalized = String(user.employeeNumber || '').replace(/\D/g, '');
  const allowed = user.role === 'manager' || normalized === '400161';
  if (!allowed || (user.accountStatus && user.accountStatus !== 'active')) {
    throw new Error('manager-only');
  }
}

function enforceRateLimit(uid) {
  const now = Date.now();
  const windowMs = 60_000;
  const limit = 12;
  const previous = requestWindows.get(uid) || [];
  const active = previous.filter((time) => now - time < windowMs);
  if (active.length >= limit) throw new Error('rate-limit');
  active.push(now);
  requestWindows.set(uid, active);
}

function sanitizeMessages(value) {
  if (!Array.isArray(value)) return [];
  return value
    .slice(-10)
    .map((item) => ({
      role: item?.role === 'assistant' ? 'assistant' : 'user',
      content: String(item?.content || '').trim().slice(0, 3000),
    }))
    .filter((item) => item.content);
}

function extractOutputText(response) {
  if (typeof response.output_text === 'string') return response.output_text;
  for (const item of response.output || []) {
    if (item.type !== 'message') continue;
    for (const content of item.content || []) {
      if (content.type === 'output_text' && typeof content.text === 'string') {
        return content.text;
      }
    }
  }
  return '';
}

function parseAgentResult(text) {
  const cleaned = text.trim().replace(/^```json\s*/i, '').replace(/\s*```$/, '');
  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    return {reply: text.trim() || 'تعذر تحليل الرد.', action: null};
  }

  const allowedTypes = new Set([
    'create_initiative',
    'create_task_draft',
    'team_summary',
    'update_agent_rule',
  ]);
  const action = parsed.action && allowedTypes.has(parsed.action.type)
    ? {
        type: parsed.action.type,
        title: String(parsed.action.title || '').slice(0, 160),
        payload: String(parsed.action.payload || '').slice(0, 3000),
        requiresApproval: true,
      }
    : null;

  return {
    reply: String(parsed.reply || 'تم تحليل طلبك.').slice(0, 4000),
    action,
  };
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return json(res, 405, {error: 'method-not-allowed'});
  if (!process.env.OPENAI_API_KEY) {
    return json(res, 503, {error: 'agent-not-configured'});
  }

  try {
    const token = bearerToken(req);
    const identity = decodeFirebaseIdentity(token);
    const user = await loadNeoTaskUser(token, identity.uid);
    enforceManager(user);
    enforceRateLimit(user.uid);

    const prompt = String(req.body?.message || '').trim();
    if (!prompt || prompt.length > 4000) {
      return json(res, 400, {error: 'invalid-message'});
    }

    const history = sanitizeMessages(req.body?.history);
    const safetyIdentifier = crypto
      .createHash('sha256')
      .update(`neotask:${user.uid}`)
      .digest('hex')
      .slice(0, 32);

    const instructions = `أنت Executive AI Agent داخل NeoTask. تخاطب مديرًا عربيًا بوضوح واختصار.\n
مهمتك تحليل طلب المدير وتحويله إلى رد عملي أو إجراء مقترح. لا تدّعِ تنفيذ أي إجراء. كل تغيير خارجي يحتاج موافقة صريحة داخل التطبيق.\n
أعد JSON فقط بالشكل التالي:\n
{"reply":"رد عربي واضح","action":null}\n
أو:\n
{"reply":"شرح ما فهمته وما سيحدث بعد الاعتماد","action":{"type":"create_initiative|create_task_draft|team_summary|update_agent_rule","title":"عنوان قصير","payload":"تفاصيل كاملة قابلة للحفظ"}}\n
استخدم create_initiative للأفكار والمبادرات. استخدم create_task_draft عند طلب إنشاء أو توزيع مهمة. استخدم team_summary عند طلب تلخيص أو تحليل أداء. استخدم update_agent_rule عند طلب تغيير سلوك المساعد أو قواعد التنبيه. لا تُخرج Markdown أو نصًا خارج JSON.`;

    const input = [
      ...history.map((item) => ({role: item.role, content: item.content})),
      {role: 'user', content: `اسم المدير: ${user.name || 'المدير'}\nطلبه: ${prompt}`},
    ];

    const openaiResponse = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        instructions,
        input,
        reasoning: {effort: 'low'},
        text: {verbosity: 'low'},
        max_output_tokens: 1200,
        safety_identifier: safetyIdentifier,
      }),
    });

    const responseBody = await openaiResponse.json();
    if (!openaiResponse.ok) {
      console.error('OpenAI request failed', {
        status: openaiResponse.status,
        code: responseBody?.error?.code || 'unknown',
      });
      return json(res, 502, {error: 'agent-provider-error'});
    }

    const result = parseAgentResult(extractOutputText(responseBody));
    return json(res, 200, {...result, requestId: responseBody.id || null});
  } catch (error) {
    const code = error?.message || 'internal';
    const status = code === 'manager-only' ? 403
      : code === 'rate-limit' ? 429
      : ['missing-token', 'invalid-token'].includes(code) ? 401
      : code === 'profile-unavailable' ? 403
      : 500;
    if (status === 500) console.error('NeoTask agent error', {code});
    return json(res, status, {error: code});
  }
}
