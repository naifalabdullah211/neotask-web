import crypto from 'node:crypto';

const FIREBASE_PROJECT_ID = 'neotask1-ff5a4';
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const OPENAI_BASE_URL = 'https://api.openai.com/v1';
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-5-mini';

const ALLOWED_ORIGINS = new Set([
  'https://neotask1-ff5a4.web.app',
  'https://neotask1-ff5a4.firebaseapp.com',
  'http://localhost:5000',
  'http://localhost:3000',
]);

const AGENTS = Object.freeze({
  executive: {
    id: 'executive',
    name: 'الوكيل التنفيذي',
    mission: 'ينسق عمل الوكلاء المتخصصين ويجمع نتائجهم للمدير.',
  },
  tasks: {
    id: 'tasks',
    name: 'وكيل المهام',
    mission: 'يحلل المهام والتأخير والاستحقاقات والأولويات والتوزيع.',
  },
  projects: {
    id: 'projects',
    name: 'وكيل المشاريع',
    mission: 'يحلل الأهداف والمبادرات والمعايير ونسب الإنجاز والمخاطر الزمنية.',
  },
  employees: {
    id: 'employees',
    name: 'وكيل الموظفين',
    mission: 'يحلل حمل الموظفين والسعة الأسبوعية والتوزيع والأداء التشغيلي.',
  },
  meetings: {
    id: 'meetings',
    name: 'وكيل الاجتماعات',
    mission: 'يراجع الاجتماعات والمحاضر والقرارات والمسؤولين والاستحقاقات.',
  },
  knowledge: {
    id: 'knowledge',
    name: 'وكيل المعرفة',
    mission: 'يبحث في السياسات والإجراءات والأدلة وصفحات المعرفة المتاحة في NeoTask فقط.',
  },
  analytics: {
    id: 'analytics',
    name: 'وكيل التحليلات',
    mission: 'يحول بيانات NeoTask إلى مؤشرات واتجاهات ومقارنات واستنتاجات محددة.',
  },
  quality: {
    id: 'quality',
    name: 'وكيل الجودة',
    mission: 'يراقب فجوات الالتزام والتأخير والمعايير ومراجعات الوثائق ويقترح إجراءات تصحيحية.',
  },
});

const requestWindows = new Map();
let firebaseCertCache = {certs: null, expiresAt: 0};
let openAiHealthCache = {ready: false, expiresAt: 0, code: ''};

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
}

function json(res, status, body) {
  res.status(status).json(body);
}

function openAiKey() {
  return String(process.env.OPENAI_API_KEY || '').trim();
}

function validOpenAiKeyFormat(key) {
  return key.startsWith('sk-') && !/[\r\n]/.test(key) && key.length >= 20;
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
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new Error('token-verification-unavailable');
  const certs = await response.json();
  const cacheControl = response.headers.get('cache-control') || '';
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/i);
  firebaseCertCache = {
    certs,
    expiresAt: now + Math.max(300, Number(maxAgeMatch?.[1] || 3600)) * 1000,
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
  if (typeof certificate !== 'string' || !certificate) throw new Error('invalid-token');
  const signatureValid = crypto.verify(
    'RSA-SHA256',
    Buffer.from(`${encodedHeader}.${encodedPayload}`, 'utf8'),
    certificate,
    Buffer.from(encodedSignature, 'base64url'),
  );
  if (!signatureValid) throw new Error('invalid-token');
  const now = Math.floor(Date.now() / 1000);
  const subject = typeof claims.sub === 'string' ? claims.sub : '';
  if (
    claims.aud !== FIREBASE_PROJECT_ID ||
    claims.iss !== FIREBASE_ISSUER ||
    !subject || subject.length > 128 ||
    typeof claims.exp !== 'number' || claims.exp <= now ||
    typeof claims.iat !== 'number' || claims.iat > now + 300 ||
    typeof claims.auth_time !== 'number' || claims.auth_time > now + 300
  ) {
    throw new Error('invalid-token');
  }
  return {uid: subject, email: claims.email || ''};
}

async function loadNeoTaskUser(token, uid) {
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
  const response = await fetch(url, {
    headers: {Authorization: `Bearer ${token}`, 'Cache-Control': 'no-store'},
    signal: AbortSignal.timeout(8000),
  });
  if (response.status === 401 || response.status === 403) throw new Error('invalid-token');
  if (!response.ok) throw new Error('profile-unavailable');
  const fields = (await response.json()).fields || {};
  const value = (key) => fields[key]?.stringValue || '';
  return {
    uid,
    name: value('name'),
    role: value('role'),
    employeeNumber: value('employeeNumber'),
    accountStatus: value('accountStatus'),
  };
}

function enforceManager(user) {
  const employeeNumber = String(user.employeeNumber || '').replace(/\D/g, '');
  const allowed = user.role === 'manager' || employeeNumber === '400161';
  if (!allowed || (user.accountStatus && user.accountStatus !== 'active')) {
    throw new Error('manager-only');
  }
}

function enforceRateLimit(uid) {
  const now = Date.now();
  const active = (requestWindows.get(uid) || []).filter((time) => now - time < 60_000);
  if (active.length >= 8) throw new Error('rate-limit');
  active.push(now);
  requestWindows.set(uid, active);
}

function normalizeText(value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return String(value || '')
    .replace(/[٠-٩]/g, (digit) => String(digits.indexOf(digit)))
    .replace(/[ًٌٍَُِّْـ]/g, '')
    .replace(/[إأآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .toLowerCase();
}

function list(value, limit = 80) {
  return Array.isArray(value) ? value.slice(0, limit) : [];
}

function sanitizeBody(body = {}) {
  return {
    prompt: String(body.message || '').trim().slice(0, 4000),
    history: list(body.history, 10).map((item) => ({
      role: item?.role === 'assistant' ? 'assistant' : 'user',
      content: String(item?.content || '').trim().slice(0, 2500),
    })).filter((item) => item.content),
    team: list(body.teamContext, 100),
    tasks: list(body.taskContext, 120),
    projects: list(body.projectContext, 60),
    meetings: list(body.meetingContext, 50),
    knowledge: list(body.knowledgeContext, 50),
    quality: body.qualityContext && typeof body.qualityContext === 'object'
      ? body.qualityContext
      : {},
    rules: list(body.agentRules, 20)
      .map((item) => String(item || '').trim().slice(0, 500))
      .filter(Boolean),
  };
}

function routeAgents(prompt) {
  const p = normalizeText(prompt);
  if (/(تقرير شامل|الوضع العام|وضع القسم|حلل القسم|كل شيء|كل شي|نظره شامله|نظرة شاملة)/.test(p)) {
    return ['tasks', 'projects', 'employees', 'meetings', 'knowledge', 'analytics', 'quality'];
  }
  const selected = new Set();
  if (/(مهمه|مهمة|مهام|متاخر|استحقاق|توزيع|اسناد|إسناد|عاجل)/.test(p)) selected.add('tasks');
  if (/(مشروع|مبادره|مبادرة|هدف|اهداف|أهداف|معيار|معايير|خطة عمل|خطه عمل)/.test(p)) selected.add('projects');
  if (/(موظف|موظفين|فريق|حمل|سعه|سعة|اداء موظف|أداء موظف|طاقه|طاقة)/.test(p)) selected.add('employees');
  if (/(اجتماع|اجتماعات|محضر|قرار اجتماع|قرارات الاجتماع|اجنده|أجندة)/.test(p)) selected.add('meetings');
  if (/(سياسه|سياسة|اجراء|إجراء|دليل|ملف|وثيقه|وثيقة|معرفه|معرفة|مركز المعرفة)/.test(p)) selected.add('knowledge');
  if (/(تحليل|احصائ|إحصائ|مؤشر|مؤشرات|kpi|تقرير|اتجاه|مقارنه|مقارنة)/.test(p)) selected.add('analytics');
  if (/(جوده|جودة|التزام|تدقيق|فجوه|فجوة|تصحيحي|مراجعه|مراجعة|اعتماد)/.test(p)) selected.add('quality');
  if (selected.size === 0) selected.add('tasks');
  return [...selected];
}

function agentContext(id, context) {
  switch (id) {
    case 'tasks': return {tasks: context.tasks, team: context.team};
    case 'projects': return {projects: context.projects, team: context.team};
    case 'employees': return {team: context.team, tasks: context.tasks.slice(0, 60)};
    case 'meetings': return {meetings: context.meetings, team: context.team};
    case 'knowledge': return {knowledge: context.knowledge};
    case 'analytics': return {
      team: context.team,
      tasks: context.tasks,
      projects: context.projects,
      meetings: context.meetings,
      quality: context.quality,
    };
    case 'quality': return {
      quality: context.quality,
      projects: context.projects,
      knowledge: context.knowledge.map((doc) => ({
        title: doc.title,
        status: doc.status,
        reviewDueDate: doc.reviewDueDate,
        department: doc.department,
      })),
    };
    default: return {};
  }
}

function extractOutputText(body) {
  if (typeof body?.output_text === 'string' && body.output_text.trim()) {
    return body.output_text.trim();
  }
  let text = '';
  for (const item of body?.output || []) {
    if (item.type !== 'message') continue;
    for (const part of item.content || []) {
      if (part.type === 'output_text' && typeof part.text === 'string') text += part.text;
    }
  }
  return text.trim();
}

async function openAiResponse({instructions, input, maxOutputTokens = 800}) {
  const key = openAiKey();
  if (!validOpenAiKeyFormat(key)) throw new Error('openai-key-invalid');
  const response = await fetch(`${OPENAI_BASE_URL}/responses`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    signal: AbortSignal.timeout(25_000),
    body: JSON.stringify({
      model: OPENAI_MODEL,
      instructions,
      input,
      reasoning: {effort: 'low'},
      text: {verbosity: 'low'},
      max_output_tokens: maxOutputTokens,
      store: false,
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const providerCode = body?.error?.code || body?.error?.type || `http-${response.status}`;
    console.error('OpenAI direct request failed', {status: response.status, code: providerCode});
    throw new Error(`openai-${response.status}-${providerCode}`);
  }
  const text = extractOutputText(body);
  if (!text) throw new Error('openai-empty-response');
  return {text, requestId: body.id || response.headers.get('x-request-id') || null};
}

async function checkOpenAiHealth({force = false} = {}) {
  const now = Date.now();
  if (!force && openAiHealthCache.expiresAt > now) return openAiHealthCache;
  const key = openAiKey();
  if (!validOpenAiKeyFormat(key)) {
    openAiHealthCache = {ready: false, expiresAt: now + 30_000, code: 'openai-key-invalid'};
    return openAiHealthCache;
  }
  try {
    const response = await fetch(`${OPENAI_BASE_URL}/models/${encodeURIComponent(OPENAI_MODEL)}`, {
      headers: {Authorization: `Bearer ${key}`},
      signal: AbortSignal.timeout(10_000),
    });
    let code = '';
    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      code = body?.error?.code || body?.error?.type || `http-${response.status}`;
    }
    openAiHealthCache = {
      ready: response.ok,
      expiresAt: now + (response.ok ? 300_000 : 30_000),
      code,
    };
  } catch (error) {
    openAiHealthCache = {
      ready: false,
      expiresAt: now + 30_000,
      code: String(error?.name || 'network'),
    };
  }
  return openAiHealthCache;
}

async function runSpecialist(id, context, today) {
  const agent = AGENTS[id];
  const instructions = `أنت ${agent.name} داخل NeoTask. ${agent.mission}\n` +
    'TruthMode إلزامي: افصل الحقائق من NeoTask عن الاستنتاجات. لا تدّعِ تنفيذ أي تغيير. لا تخترع بيانات. ' +
    `التاريخ في السعودية: ${today}. أجب بنقاط عربية قصيرة موجهة للوكيل التنفيذي.`;
  const input = `طلب المدير: ${context.prompt}\nبيانات نطاقك الحية: ${JSON.stringify(agentContext(id, context))}`;
  const result = await openAiResponse({instructions, input, maxOutputTokens: 650});
  return {id, name: agent.name, status: 'completed-ai', report: result.text};
}

function addDays(isoDate, days) {
  const date = new Date(`${isoDate}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function requestedDueDate(prompt, today) {
  const p = normalizeText(prompt);
  const explicit = p.match(/\b(20\d{2}-\d{2}-\d{2})\b/);
  if (explicit) return explicit[1];
  if (/(غدا|غد|بكره|بكرة)/.test(p)) return addDays(today, 1);
  const relative = p.match(/بعد\s+(\d{1,3})\s+(?:يوم|ايام)/);
  return relative ? addDays(today, Math.max(1, Number(relative[1]))) : '';
}

function matchEmployee(prompt, team) {
  const p = normalizeText(prompt);
  return [...team]
    .sort((a, b) => String(b.name || '').length - String(a.name || '').length)
    .find((employee) => {
      const name = normalizeText(employee.name).trim();
      const number = normalizeText(employee.employeeNumber).trim();
      return (name.length >= 2 && p.includes(name)) || (number && p.includes(number));
    }) || null;
}

function deterministicAction(context, today) {
  const p = normalizeText(context.prompt);
  if (/(قاعده|قاعدة|من الان|دائما|تذكر)/.test(p)) {
    return {
      reply: 'جهزت القاعدة كمسودة وتنتظر اعتمادك؛ لم تُحفظ بعد.',
      action: {
        type: 'update_agent_rule',
        title: 'قاعدة دائمة للوكيل',
        payload: context.prompt,
        employeeUid: '', employeeNumber: '', employeeName: '', dueDate: '',
        priority: 'medium', plannedHours: 1, category: 'عام', requiresApproval: true,
      },
    };
  }
  const wantsTask = /(مهمه|مهمة|كلف|اسند|إسناد)/.test(p);
  const wantsInitiative = /(مبادره|مبادرة|فكره|فكرة)/.test(p);
  if (!wantsTask && !wantsInitiative) return null;
  const employee = matchEmployee(context.prompt, context.team);
  if (!employee) return {reply: 'حدد اسم الموظف أو رقمه الوظيفي قبل تجهيز الإجراء.', action: null};
  const dueDate = requestedDueDate(context.prompt, today);
  if (!dueDate) return {reply: `حدد موعد الاستحقاق لـ ${employee.name} قبل تجهيز الإجراء.`, action: null};
  return {
    reply: `جهزت ${wantsInitiative ? 'المبادرة' : 'المهمة'} كمسودة لـ ${employee.name}. لم تُنشأ بعد؛ اعتمادك هو الذي ينفذها.`,
    action: {
      type: wantsInitiative ? 'create_initiative' : 'create_task_draft',
      title: context.prompt.slice(0, 160),
      payload: context.prompt.slice(0, 3000),
      employeeUid: employee.uid,
      employeeNumber: employee.employeeNumber,
      employeeName: employee.name,
      dueDate,
      priority: /(عاجل|ضروري|عاليه|عالية)/.test(p) ? 'high' : 'medium',
      plannedHours: 1,
      category: 'عام',
      requiresApproval: true,
    },
  };
}

function parseExecutive(text) {
  const cleaned = String(text || '').trim().replace(/^```json\s*/i, '').replace(/\s*```$/, '');
  try {
    const parsed = JSON.parse(cleaned);
    const rawAction = parsed.action;
    const allowedTypes = new Set(['create_task_draft', 'create_initiative', 'team_summary', 'update_agent_rule']);
    const action = rawAction && allowedTypes.has(rawAction.type)
      ? {
          type: rawAction.type,
          title: String(rawAction.title || '').slice(0, 160),
          payload: String(rawAction.payload || '').slice(0, 3000),
          employeeUid: String(rawAction.employeeUid || '').slice(0, 128),
          employeeNumber: String(rawAction.employeeNumber || '').slice(0, 40),
          employeeName: String(rawAction.employeeName || '').slice(0, 120),
          dueDate: String(rawAction.dueDate || '').slice(0, 10),
          priority: ['low', 'medium', 'high'].includes(rawAction.priority) ? rawAction.priority : 'medium',
          plannedHours: Math.min(168, Math.max(0.25, Number(rawAction.plannedHours) || 1)),
          category: String(rawAction.category || 'عام').slice(0, 80),
          requiresApproval: true,
        }
      : null;
    return {reply: String(parsed.reply || 'تم تحليل طلبك.').slice(0, 4000), action};
  } catch {
    return {reply: String(text || '').slice(0, 4000), action: null};
  }
}

async function runExecutive(context, user, specialistReports, today) {
  const instructions = `أنت ${AGENTS.executive.name} داخل NeoTask. ${AGENTS.executive.mission}\n` +
    'TruthMode إلزامي: لا تقل تم التنفيذ أو تم الحفظ أو تم الإرسال إلا إذا ورد دليل تنفيذ فعلي من NeoTask. ' +
    'تقارير الوكلاء تحليل وليست تنفيذًا. افصل الحقائق عن الاستنتاجات. لا تخترع أي بيانات. ' +
    `التاريخ في السعودية: ${today}. أعد JSON فقط بالشكل ` +
    '{"reply":"رد عربي واضح","action":null}. استخدم action فقط إذا كان الإجراء قابلاً للاعتماد داخل NeoTask.';
  const input = `اسم المدير: ${user.name || 'المدير'}\n` +
    `طلب المدير: ${context.prompt}\n` +
    `قواعد المدير: ${JSON.stringify(context.rules)}\n` +
    `تقارير الوكلاء: ${JSON.stringify(specialistReports)}`;
  const result = await openAiResponse({instructions, input, maxOutputTokens: 1100});
  return {...parseExecutive(result.text), requestId: result.requestId};
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();

  if (req.method === 'GET') {
    const health = await checkOpenAiHealth();
    return json(res, health.ready ? 200 : 503, {
      status: health.ready ? 'ready' : 'degraded',
      provider: health.ready ? 'openai-direct' : 'unavailable',
      model: OPENAI_MODEL,
      count: 8,
      agents: Object.values(AGENTS).map(({id, name}) => ({id, name})),
      error: health.ready ? undefined : health.code || 'openai-unavailable',
    });
  }

  if (req.method !== 'POST') return json(res, 405, {error: 'method-not-allowed'});

  try {
    const health = await checkOpenAiHealth();
    if (!health.ready) {
      return json(res, 503, {error: health.code || 'openai-unavailable'});
    }

    const token = bearerToken(req);
    const identity = await verifyFirebaseIdentity(token);
    const user = await loadNeoTaskUser(token, identity.uid);
    enforceManager(user);
    enforceRateLimit(user.uid);

    const context = sanitizeBody(req.body || {});
    if (!context.prompt) return json(res, 400, {error: 'invalid-message'});

    const today = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh',
      year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date());

    const selected = routeAgents(context.prompt);
    const specialistReports = await Promise.all(
      selected.map((id) => runSpecialist(id, context, today)),
    );

    const deterministic = deterministicAction(context, today);
    let finalResult;
    let requestId = null;
    if (deterministic) {
      finalResult = deterministic;
    } else {
      const executive = await runExecutive(context, user, specialistReports, today);
      finalResult = {reply: executive.reply, action: executive.action};
      requestId = executive.requestId;
    }

    return json(res, 200, {
      ...finalResult,
      delegatedAgents: [
        {id: 'executive', name: AGENTS.executive.name, status: 'completed-ai'},
        ...specialistReports.map(({id, name, status}) => ({id, name, status})),
      ],
      requestId,
      mode: 'openai-direct',
      model: OPENAI_MODEL,
    });
  } catch (error) {
    const raw = error?.message || '';
    const known = new Set([
      'manager-only',
      'rate-limit',
      'missing-token',
      'invalid-token',
      'profile-unavailable',
      'token-verification-unavailable',
      'openai-key-invalid',
    ]);
    const code = known.has(raw)
      ? raw
      : raw.startsWith('openai-')
        ? 'openai-provider-error'
        : 'internal';
    const status = code === 'manager-only' ? 403
      : code === 'rate-limit' ? 429
      : ['missing-token', 'invalid-token'].includes(code) ? 401
      : code === 'profile-unavailable' ? 403
      : ['token-verification-unavailable', 'openai-key-invalid', 'openai-provider-error'].includes(code) ? 503
      : 500;
    if (status >= 500) console.error('NeoTask OpenAI agent error', {code});
    return json(res, status, {error: code});
  }
}
