import crypto from 'node:crypto';

const FIREBASE_PROJECT_ID = 'neotask1-ff5a4';
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const GATEWAY_BASE_URL = 'https://ai-gateway.vercel.sh/v1';
const GATEWAY_MODEL = process.env.AI_GATEWAY_MODEL ||
  'google/gemini-3.5-flash-lite';
const ALLOWED_ORIGINS = new Set([
  'https://neotask1-ff5a4.web.app',
  'https://neotask1-ff5a4.firebaseapp.com',
  'http://localhost:5000',
  'http://localhost:3000',
]);

const requestWindows = new Map();
let providerHealthCache = {ready: false, expiresAt: 0};
let firebaseCertCache = {
  certs: null,
  expiresAt: 0,
};

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type');
  res.setHeader('Cache-Control', 'no-store');
}

export function normalizeProviderKey(value) {
  return String(value || '').replace(/\s+/g, '');
}

export function resolveGatewayCredential(env = process.env) {
  // Vercel injects a short-lived OIDC token into every deployment. Prefer it
  // over manually managed keys so NeoTask cannot be broken by a copied,
  // malformed, expired, or leaked provider key again.
  return normalizeProviderKey(env.VERCEL_OIDC_TOKEN) ||
    normalizeProviderKey(env.AI_GATEWAY_API_KEY);
}

async function providerIsReady(credential) {
  const now = Date.now();
  if (providerHealthCache.expiresAt > now) return providerHealthCache.ready;

  if (!credential) {
    providerHealthCache = {ready: false, expiresAt: now + 15_000};
    return false;
  }

  try {
    const response = await fetch(`${GATEWAY_BASE_URL}/models`, {
      headers: {Authorization: `Bearer ${credential}`},
      signal: AbortSignal.timeout(8000),
    });
    providerHealthCache = {
      ready: response.ok,
      expiresAt: now + (response.ok ? 60_000 : 15_000),
    };
  } catch {
    providerHealthCache = {ready: false, expiresAt: now + 15_000};
  }
  return providerHealthCache.ready;
}

function normalizeArabicText(value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return String(value || '')
    .replace(/[٠-٩]/g, (digit) => String(digits.indexOf(digit)))
    .replace(/[ًٌٍَُِّْـ]/g, '')
    .replace(/[إأآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .toLowerCase();
}

function addDays(isoDate, days) {
  const date = new Date(`${isoDate}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function requestedDueDate(prompt, today) {
  const normalized = normalizeArabicText(prompt);
  const explicit = normalized.match(/\b(20\d{2}-\d{2}-\d{2})\b/);
  if (explicit) return explicit[1];
  if (/(غدا|غد|بكره|بكرة)/.test(normalized)) return addDays(today, 1);
  const relative = normalized.match(/بعد\s+(\d{1,3})\s+(?:يوم|ايام)/);
  if (relative) return addDays(today, Math.max(1, Number(relative[1])));
  return '';
}

function matchingEmployee(prompt, teamContext) {
  const normalized = normalizeArabicText(prompt);
  return [...teamContext]
    .sort((a, b) => b.name.length - a.name.length)
    .find((employee) => {
      const employeeNumber = normalizeArabicText(employee.employeeNumber);
      const employeeName = normalizeArabicText(employee.name).trim();
      return (employeeNumber && normalized.includes(employeeNumber)) ||
        (employeeName.length >= 2 && normalized.includes(employeeName));
    }) || null;
}

export function buildLocalFallback({prompt, teamContext, today}) {
  const normalized = normalizeArabicText(prompt);
  const hasAny = (words) => words.some((word) => normalized.includes(word));

  if (hasAny(['لخص', 'ملخص', 'حلل', 'اداء الفريق'])) {
    const activeTasks = teamContext.reduce(
      (sum, employee) => sum + employee.activeTasks,
      0,
    );
    const overdueTasks = teamContext.reduce(
      (sum, employee) => sum + employee.overdueTasks,
      0,
    );
    const plannedHours = teamContext.reduce(
      (sum, employee) => sum + employee.plannedHours,
      0,
    );
    const busiest = [...teamContext].sort(
      (a, b) => b.plannedHours - a.plannedHours,
    )[0];
    return {
      reply: teamContext.length
        ? `الفريق يضم ${teamContext.length} موظفًا نشطًا، ولديه ${activeTasks} مهمة نشطة منها ${overdueTasks} متأخرة بإجمالي ${plannedHours.toFixed(1)} ساعة مخططة.` +
          (busiest ? ` أعلى حمل حاليًا لدى ${busiest.name} (${busiest.plannedHours.toFixed(1)} ساعة).` : '')
        : 'لا توجد بيانات موظفين نشطين متاحة للتحليل الآن.',
      action: null,
    };
  }

  if (hasAny(['قاعده', 'قاعدة', 'دائما', 'من الان', 'تذكر'])) {
    return {
      reply: 'فهمت القاعدة. سأعرضها لك للاعتماد قبل حفظها ضمن تعليمات الوكيل الدائمة.',
      action: {
        type: 'update_agent_rule',
        title: 'قاعدة دائمة للوكيل',
        payload: String(prompt).trim().slice(0, 500),
        employeeUid: '',
        employeeNumber: '',
        employeeName: '',
        dueDate: '',
        priority: 'medium',
        plannedHours: 1,
        category: 'عام',
        requiresApproval: true,
      },
    };
  }

  if (hasAny(['مهمه', 'مهمة', 'كلف', 'اسند', 'حوّل', 'حول'])) {
    const employee = matchingEmployee(prompt, teamContext);
    if (!employee) {
      return {reply: 'حدد اسم الموظف أو رقمه الوظيفي حتى أجهز المهمة بدقة.', action: null};
    }
    const dueDate = requestedDueDate(prompt, today);
    if (!dueDate) {
      return {reply: `حدد موعد الاستحقاق لمهمة ${employee.name}، مثل غدًا أو 2026-08-15.`, action: null};
    }
    const highPriority = hasAny(['عاجل', 'عاليه', 'عالية', 'ضروري']);
    return {
      reply: `جهزت المهمة لـ ${employee.name}. راجع التفاصيل ثم اضغط اعتماد لإنشائها فعليًا.`,
      action: {
        type: 'create_task_draft',
        title: String(prompt).trim().slice(0, 160),
        payload: String(prompt).trim().slice(0, 3000),
        employeeUid: employee.uid,
        employeeNumber: employee.employeeNumber,
        employeeName: employee.name,
        dueDate,
        priority: highPriority ? 'high' : 'medium',
        plannedHours: 1,
        category: 'عام',
        requiresApproval: true,
      },
    };
  }

  if (hasAny(['مبادره', 'مبادرة', 'فكره', 'فكرة', 'مشروع'])) {
    return {
      reply: 'جهزت الفكرة كمبادرة. راجعها ثم اعتمدها لإضافتها إلى سجل المساعد.',
      action: {
        type: 'create_initiative',
        title: String(prompt).trim().slice(0, 160),
        payload: String(prompt).trim().slice(0, 3000),
        employeeUid: '',
        employeeNumber: '',
        employeeName: '',
        dueDate: '',
        priority: 'medium',
        plannedHours: 1,
        category: 'عام',
        requiresApproval: true,
      },
    };
  }

  return {
    reply: 'أنا جاهز. اطلب مني إنشاء مهمة باسم الموظف وموعدها، أو تلخيص أداء الفريق، أو حفظ قاعدة دائمة، أو تجهيز مبادرة.',
    action: null,
  };
}

function json(res, status, body) {
  res.status(status).json(body);
}

function bearerToken(req) {
  const value = req.headers.authorization || '';
  return value.startsWith('Bearer ') ? value.slice(7).trim() : '';
}

function decodeJwtJson(part) {
  try {
    return JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
  } catch {
    throw new Error('invalid-token');
  }
}

async function getFirebasePublicCerts() {
  const now = Date.now();
  if (firebaseCertCache.certs && firebaseCertCache.expiresAt > now) {
    return firebaseCertCache.certs;
  }

  const response = await fetch(FIREBASE_CERTS_URL, {
    headers: {'Cache-Control': 'no-cache'},
  });
  if (!response.ok) throw new Error('token-verification-unavailable');

  const certs = await response.json();
  if (!certs || typeof certs !== 'object') {
    throw new Error('token-verification-unavailable');
  }

  const cacheControl = response.headers.get('cache-control') || '';
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/i);
  const maxAgeSeconds = maxAgeMatch ? Number(maxAgeMatch[1]) : 3600;
  firebaseCertCache = {
    certs,
    expiresAt: now + Math.max(300, maxAgeSeconds) * 1000,
  };
  return certs;
}

async function verifyFirebaseIdentity(token) {
  if (!token || token.length > 8192) throw new Error('missing-token');

  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('invalid-token');

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const header = decodeJwtJson(encodedHeader);
  const claims = decodeJwtJson(encodedPayload);

  if (header.alg !== 'RS256' || typeof header.kid !== 'string' || !header.kid) {
    throw new Error('invalid-token');
  }

  const certs = await getFirebasePublicCerts();
  const certificate = certs[header.kid];
  if (typeof certificate !== 'string' || !certificate) {
    throw new Error('invalid-token');
  }

  let signature;
  try {
    signature = Buffer.from(encodedSignature, 'base64url');
  } catch {
    throw new Error('invalid-token');
  }

  const signingInput = Buffer.from(`${encodedHeader}.${encodedPayload}`, 'utf8');
  const signatureValid = crypto.verify(
    'RSA-SHA256',
    signingInput,
    certificate,
    signature,
  );
  if (!signatureValid) throw new Error('invalid-token');

  const now = Math.floor(Date.now() / 1000);
  const subject = typeof claims.sub === 'string' ? claims.sub : '';
  if (
    claims.aud !== FIREBASE_PROJECT_ID ||
    claims.iss !== FIREBASE_ISSUER ||
    !subject ||
    subject.length > 128 ||
    typeof claims.exp !== 'number' ||
    claims.exp <= now ||
    typeof claims.iat !== 'number' ||
    claims.iat > now + 300 ||
    typeof claims.auth_time !== 'number' ||
    claims.auth_time > now + 300
  ) {
    throw new Error('invalid-token');
  }

  return {uid: subject, email: claims.email || ''};
}

async function loadNeoTaskUser(token, uid) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Cache-Control': 'no-store',
    },
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

function sanitizeTeamContext(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 80).map((item) => ({
    uid: String(item?.uid || '').slice(0, 128),
    name: String(item?.name || '').slice(0, 120),
    employeeNumber: String(item?.employeeNumber || '').slice(0, 40),
    weeklyCapacityHours: Number(item?.weeklyCapacityHours || 0),
    activeTasks: Number(item?.activeTasks || 0),
    overdueTasks: Number(item?.overdueTasks || 0),
    plannedHours: Number(item?.plannedHours || 0),
  })).filter((item) => item.uid && item.name);
}

function sanitizeAgentRules(value) {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, 20)
    .map((item) => String(item || '').trim().slice(0, 500))
    .filter(Boolean);
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
  const rawAction = parsed.action;
  let action = rawAction && allowedTypes.has(rawAction.type)
    ? {
        type: rawAction.type,
        title: String(rawAction.title || '').trim().slice(0, 160),
        payload: String(rawAction.payload || '').trim().slice(0, 3000),
        employeeUid: String(rawAction.employeeUid || '').trim().slice(0, 128),
        employeeNumber: String(rawAction.employeeNumber || '').trim().slice(0, 40),
        employeeName: String(rawAction.employeeName || '').trim().slice(0, 120),
        dueDate: String(rawAction.dueDate || '').trim().slice(0, 10),
        priority: ['low', 'medium', 'high'].includes(rawAction.priority)
          ? rawAction.priority
          : 'medium',
        plannedHours: Math.min(168, Math.max(0.25, Number(rawAction.plannedHours) || 1)),
        category: String(rawAction.category || 'عام').trim().slice(0, 80),
        requiresApproval: true,
      }
    : null;

  if (action?.type === 'create_task_draft') {
    const validDate = /^\d{4}-\d{2}-\d{2}$/.test(action.dueDate);
    if (!action.title || !action.payload || !action.employeeUid || !validDate) {
      action = null;
    }
  }

  return {
    reply: String(parsed.reply || 'تم تحليل طلبك.').slice(0, 4000),
    action,
  };
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  const gatewayCredential = resolveGatewayCredential();
  if (req.method === 'GET') {
    const providerReady = await providerIsReady(gatewayCredential);
    return json(res, 200, {
      status: 'ready',
      mode: providerReady ? 'ai-gateway' : 'resilient-local',
    });
  }
  if (req.method !== 'POST') {
    return json(res, 405, {error: 'method-not-allowed'});
  }
  try {
    const token = bearerToken(req);
    const identity = await verifyFirebaseIdentity(token);
    const user = await loadNeoTaskUser(token, identity.uid);
    enforceManager(user);
    enforceRateLimit(user.uid);

    const prompt = String(req.body?.message || '').trim();
    if (!prompt || prompt.length > 4000) {
      return json(res, 400, {error: 'invalid-message'});
    }

    const history = sanitizeMessages(req.body?.history);
    const teamContext = sanitizeTeamContext(req.body?.teamContext);
    const agentRules = sanitizeAgentRules(req.body?.agentRules);
    const todayInRiyadh = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());

    const instructions = `أنت Executive AI Agent داخل NeoTask. تخاطب مديرًا عربيًا بوضوح واختصار.\n
مهمتك تحليل طلب المدير وتحويله إلى رد عملي أو إجراء مقترح. لا تدّعِ تنفيذ أي إجراء. كل تغيير خارجي يحتاج موافقة صريحة داخل التطبيق.\n
التاريخ الحالي في السعودية: ${todayInRiyadh}. التزم بقواعد المدير الدائمة الواردة في السياق ما لم يتعارض طلبه الحالي معها. عند تحليل الفريق اعتمد حصريًا على بيانات NeoTask الحية الواردة في السياق ولا تخترع بيانات.\n
أعد JSON فقط بالشكل التالي:\n
{"reply":"رد عربي واضح","action":null}\n
أو:\n
{"reply":"شرح ما فهمته وما سيحدث بعد الاعتماد","action":{"type":"create_initiative|create_task_draft|team_summary|update_agent_rule","title":"عنوان قصير","payload":"تفاصيل كاملة قابلة للحفظ","employeeUid":"uid من بيانات الفريق","employeeNumber":"الرقم الوظيفي","employeeName":"اسم الموظف","dueDate":"YYYY-MM-DD","priority":"low|medium|high","plannedHours":1,"category":"عام"}}\n
استخدم create_initiative للأفكار والمبادرات. استخدم create_task_draft عند طلب إنشاء أو توزيع مهمة، وانسخ employeeUid والرقم والاسم حرفيًا من بيانات الفريق، وحدد تاريخًا مستقبليًا واضحًا. إذا لم يحدد المدير الموظف أو الموعد ولم يمكن استنتاجهما بأمان، اسأله عنهما وأعد action:null. استخدم team_summary عند طلب تلخيص أو تحليل أداء. استخدم update_agent_rule عند طلب تغيير سلوك المساعد أو قواعد التنبيه، واجعل payload نص القاعدة الدائمة نفسها. لا تُخرج Markdown أو نصًا خارج JSON.`;

    const input = [
      ...history.map((item) => ({role: item.role, content: item.content})),
      {
        role: 'user',
        content: `اسم المدير: ${user.name || 'المدير'}\n` +
          `قواعد المدير الدائمة: ${agentRules.length ? JSON.stringify(agentRules) : 'لا توجد'}\n` +
          `بيانات الفريق الحية: ${teamContext.length ? JSON.stringify(teamContext) : 'لا يوجد موظفون نشطون'}\n` +
          `طلبه: ${prompt}`,
      },
    ];

    if (gatewayCredential) {
      try {
        const gatewayResponse = await fetch(`${GATEWAY_BASE_URL}/responses`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${gatewayCredential}`,
            'Content-Type': 'application/json',
          },
          signal: AbortSignal.timeout(25_000),
          body: JSON.stringify({
            model: GATEWAY_MODEL,
            instructions,
            input,
            max_output_tokens: 1200,
            providerOptions: {
              gateway: {
                models: [GATEWAY_MODEL, 'openai/gpt-5.6-sol'],
              },
            },
          }),
        });

        const responseBody = await gatewayResponse.json();
        if (gatewayResponse.ok) {
          const result = parseAgentResult(extractOutputText(responseBody));
          return json(res, 200, {
            ...result,
            requestId: responseBody.id || null,
            mode: 'ai-gateway',
          });
        }
        console.error('AI Gateway request failed', {
          status: gatewayResponse.status,
          code: responseBody?.error?.code || 'unknown',
        });
      } catch (error) {
        console.error('AI Gateway unavailable', {
          code: error?.name === 'TimeoutError' ? 'timeout' : 'network',
        });
      }
    }

    const fallback = buildLocalFallback({
      prompt,
      teamContext,
      today: todayInRiyadh,
    });
    return json(res, 200, {
      ...fallback,
      requestId: null,
      mode: 'resilient-local',
    });
  } catch (error) {
    const knownCodes = new Set([
      'manager-only',
      'rate-limit',
      'missing-token',
      'invalid-token',
      'profile-unavailable',
      'token-verification-unavailable',
    ]);
    const rawCode = error?.message || '';
    const code = knownCodes.has(rawCode) ? rawCode : 'internal';
    const status = code === 'manager-only' ? 403
      : code === 'rate-limit' ? 429
      : ['missing-token', 'invalid-token'].includes(code) ? 401
      : code === 'profile-unavailable' ? 403
      : code === 'token-verification-unavailable' ? 503
      : 500;
    if (status >= 500) console.error('NeoTask agent error', {code});
    return json(res, status, {error: code});
  }
}
