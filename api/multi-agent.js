import crypto from 'node:crypto';
import { generateText } from 'ai';

const FIREBASE_PROJECT_ID = 'neotask1-ff5a4';
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const MODEL = process.env.AI_GATEWAY_MODEL || 'openai/gpt-5.6-sol';
const ALLOWED_ORIGINS = new Set([
  'https://neotask1-ff5a4.web.app',
  'https://neotask1-ff5a4.firebaseapp.com',
  'http://localhost:5000',
  'http://localhost:3000',
]);

const AGENTS = Object.freeze({
  executive: {
    id: 'executive',
    nameAr: 'الوكيل التنفيذي',
    mission: 'ينسق عمل الوكلاء المتخصصين، يجمع نتائجهم، ويحوّل طلب المدير إلى قرار أو إجراء واضح وقابل للاعتماد.',
  },
  tasks: {
    id: 'tasks',
    nameAr: 'وكيل المهام',
    mission: 'يحلل المهام والتأخير والاستحقاقات والأولويات والتوزيع ويقترح إجراءات تشغيلية دقيقة.',
  },
  projects: {
    id: 'projects',
    nameAr: 'وكيل المشاريع',
    mission: 'يتابع الأهداف والمبادرات والمعايير ونسب الإنجاز والمخاطر الزمنية وخطط العمل.',
  },
  employees: {
    id: 'employees',
    nameAr: 'وكيل الموظفين',
    mission: 'يحلل حمل الموظفين والسعة الأسبوعية وتوزيع العمل ومؤشرات الأداء التشغيلية.',
  },
  meetings: {
    id: 'meetings',
    nameAr: 'وكيل الاجتماعات',
    mission: 'يراجع الاجتماعات والمحاضر والقرارات والمسؤولين والمواعيد والقرارات غير المرتبطة بمهام.',
  },
  knowledge: {
    id: 'knowledge',
    nameAr: 'وكيل المعرفة',
    mission: 'يبحث في السياسات والإجراءات والأدلة وصفحات المعرفة ويجيب من المحتوى المتاح في NeoTask فقط.',
  },
  analytics: {
    id: 'analytics',
    nameAr: 'وكيل التحليلات',
    mission: 'يحوّل بيانات NeoTask إلى مؤشرات واتجاهات ومقارنات، ويفصل الحقائق عن الاستنتاجات.',
  },
  quality: {
    id: 'quality',
    nameAr: 'وكيل الجودة',
    mission: 'يراقب فجوات الالتزام والتأخير والمعايير ومراجعات الوثائق ويقترح إجراءات تصحيحية.',
  },
});

const requestWindows = new Map();
let firebaseCertCache = { certs: null, expiresAt: 0 };
let aiHealthCache = { ready: false, checkedAt: 0, error: '' };

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

function json(res, status, body) {
  res.status(status).json(body);
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
    headers: { 'Cache-Control': 'no-cache' },
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
  const valid = crypto.verify(
    'RSA-SHA256',
    Buffer.from(`${encodedHeader}.${encodedPayload}`, 'utf8'),
    certificate,
    Buffer.from(encodedSignature, 'base64url'),
  );
  if (!valid) throw new Error('invalid-token');
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
  return { uid: subject, email: claims.email || '' };
}

async function loadNeoTaskUser(token, uid) {
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}`, 'Cache-Control': 'no-store' },
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
    rules: list(body.agentRules, 20).map((item) => String(item || '').trim().slice(0, 500)).filter(Boolean),
    truthMode: body.truthMode === true,
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
    case 'tasks':
      return { tasks: context.tasks, team: context.team };
    case 'projects':
      return { projects: context.projects, team: context.team };
    case 'employees':
      return { team: context.team, tasks: context.tasks.slice(0, 60) };
    case 'meetings':
      return { meetings: context.meetings, team: context.team };
    case 'knowledge':
      return { knowledge: context.knowledge };
    case 'analytics':
      return {
        team: context.team,
        tasks: context.tasks,
        projects: context.projects,
        meetings: context.meetings,
        quality: context.quality,
      };
    case 'quality':
      return {
        quality: context.quality,
        projects: context.projects,
        knowledge: context.knowledge.map((doc) => ({
          title: doc.title,
          status: doc.status,
          reviewDueDate: doc.reviewDueDate,
          department: doc.department,
        })),
      };
    default:
      return {};
  }
}

async function aiText({ system, prompt, maxOutputTokens = 800 }) {
  const result = await generateText({
    model: MODEL,
    system,
    prompt,
    maxOutputTokens,
    abortSignal: AbortSignal.timeout(22000),
  });
  const text = String(result.text || '').trim();
  if (!text) throw new Error('empty-ai-response');
  return {
    text,
    requestId: result.response?.id || null,
  };
}

async function checkAiHealth({ force = false } = {}) {
  const now = Date.now();
  if (!force && now - aiHealthCache.checkedAt < 60_000) return aiHealthCache;
  try {
    const result = await aiText({
      system: 'Return exactly OK.',
      prompt: 'health',
      maxOutputTokens: 8,
    });
    aiHealthCache = {
      ready: result.text.toUpperCase().includes('OK'),
      checkedAt: now,
      error: '',
    };
  } catch (error) {
    const message = String(error?.message || error?.name || 'unknown').slice(0, 240);
    console.error('NeoTask AI Gateway health failed', { code: message });
    aiHealthCache = { ready: false, checkedAt: now, error: message };
  }
  return aiHealthCache;
}

async function runSpecialist(id, context, today) {
  const agent = AGENTS[id];
  const system = `أنت ${agent.nameAr} داخل NeoTask. ${agent.mission}\n` +
    `TruthMode إلزامي: افصل الحقائق المستخرجة من بيانات NeoTask عن الاستنتاجات. ` +
    `لا تدّعِ تنفيذ أي تغيير، ولا تخترع أسماء أو أرقامًا أو حالات غير موجودة في البيانات. ` +
    `إذا كانت البيانات غير كافية فقل غير متحقق. التاريخ في السعودية: ${today}. ` +
    `أجب للوكيل التنفيذي بنقاط عملية قصيرة.`;
  const prompt = `طلب المدير: ${context.prompt}\n` +
    `بيانات نطاقك الحية من NeoTask: ${JSON.stringify(agentContext(id, context))}`;
  const result = await aiText({ system, prompt, maxOutputTokens: 700 });
  return {
    id,
    name: agent.nameAr,
    status: 'completed-ai',
    report: result.text,
    requestId: result.requestId,
  };
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
      type: 'update_agent_rule',
      title: 'قاعدة دائمة للوكيل',
      payload: context.prompt,
      employeeUid: '', employeeNumber: '', employeeName: '', dueDate: '',
      priority: 'medium', plannedHours: 1, category: 'عام', requiresApproval: true,
    };
  }
  const wantsTask = /(مهمه|مهمة|كلف|اسند|إسناد)/.test(p);
  const wantsInitiative = /(مبادره|مبادرة|فكره|فكرة)/.test(p);
  if (!wantsTask && !wantsInitiative) return null;
  const employee = matchEmployee(context.prompt, context.team);
  const dueDate = requestedDueDate(context.prompt, today);
  if (!employee || !dueDate) return null;
  return {
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
  };
}

function parseExecutive(text) {
  const cleaned = String(text || '').trim()
    .replace(/^```json\s*/i, '')
    .replace(/\s*```$/, '');
  try {
    const parsed = JSON.parse(cleaned);
    const allowed = new Set([
      'create_task_draft',
      'create_initiative',
      'update_agent_rule',
      'team_summary',
    ]);
    const raw = parsed.action;
    const action = raw && typeof raw === 'object' && allowed.has(String(raw.type || ''))
      ? {
          type: String(raw.type),
          title: String(raw.title || '').slice(0, 160),
          payload: String(raw.payload || '').slice(0, 3000),
          employeeUid: String(raw.employeeUid || '').slice(0, 128),
          employeeNumber: String(raw.employeeNumber || '').slice(0, 40),
          employeeName: String(raw.employeeName || '').slice(0, 120),
          dueDate: String(raw.dueDate || '').slice(0, 10),
          priority: ['low', 'medium', 'high'].includes(raw.priority) ? raw.priority : 'medium',
          plannedHours: Math.min(168, Math.max(0.25, Number(raw.plannedHours) || 1)),
          category: String(raw.category || 'عام').slice(0, 80),
          requiresApproval: true,
        }
      : null;
    return {
      reply: String(parsed.reply || 'تم تحليل طلبك.').slice(0, 4000),
      action,
    };
  } catch {
    return { reply: String(text || '').slice(0, 4000), action: null };
  }
}

function validateAction(action, context, today) {
  if (!action) return null;
  if (action.type === 'create_task_draft' || action.type === 'create_initiative') {
    const employee = context.team.find((item) => item.uid === action.employeeUid);
    const validDate = /^\d{4}-\d{2}-\d{2}$/.test(action.dueDate) && action.dueDate >= today;
    if (!employee || !validDate) return null;
    return {
      ...action,
      employeeNumber: String(employee.employeeNumber || ''),
      employeeName: String(employee.name || ''),
      requiresApproval: true,
    };
  }
  return { ...action, requiresApproval: true };
}

async function runExecutive({ context, user, specialistReports, today }) {
  const system = `${AGENTS.executive.nameAr}: ${AGENTS.executive.mission}\n` +
    `TruthMode إلزامي: تقارير الوكلاء هي تحليل وليست تنفيذًا. لا تقل تم التنفيذ أو تم الحفظ أو تم الإرسال ` +
    `إلا إذا كان هناك دليل تنفيذ فعلي من NeoTask، وهو غير موجود في هذه المرحلة قبل اعتماد المدير. ` +
    `اعتمد فقط على بيانات NeoTask وتقارير الوكلاء. إذا كان هناك نقص فاذكره بوضوح.\n` +
    `أعد JSON فقط بالشكل: {"reply":"رد عربي واضح","action":null} أو ` +
    `{"reply":"شرح مختصر","action":{"type":"create_task_draft|create_initiative|update_agent_rule|team_summary",` +
    `"title":"عنوان","payload":"تفاصيل","employeeUid":"","employeeNumber":"","employeeName":"",` +
    `"dueDate":"YYYY-MM-DD","priority":"low|medium|high","plannedHours":1,"category":"عام"}}.`;
  const prompt = `اسم المدير: ${user.name || 'المدير'}\n` +
    `التاريخ في السعودية: ${today}\n` +
    `طلب المدير: ${context.prompt}\n` +
    `قواعد المدير الدائمة: ${JSON.stringify(context.rules)}\n` +
    `تقارير الوكلاء المتخصصين: ${JSON.stringify(specialistReports)}`;
  const result = await aiText({ system, prompt, maxOutputTokens: 1200 });
  return { ...parseExecutive(result.text), requestId: result.requestId };
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();

  if (req.method === 'GET') {
    const health = await checkAiHealth();
    return json(res, health.ready ? 200 : 503, {
      status: health.ready ? 'ready' : 'degraded',
      provider: health.ready ? 'ai-gateway' : 'unavailable',
      model: MODEL,
      agents: Object.values(AGENTS).map(({ id, nameAr }) => ({ id, name: nameAr })),
      count: 8,
    });
  }

  if (req.method !== 'POST') return json(res, 405, { error: 'method-not-allowed' });

  try {
    const token = bearerToken(req);
    const identity = await verifyFirebaseIdentity(token);
    const user = await loadNeoTaskUser(token, identity.uid);
    enforceManager(user);
    enforceRateLimit(user.uid);

    const context = sanitizeBody(req.body || {});
    if (!context.prompt) return json(res, 400, { error: 'invalid-message' });

    const health = await checkAiHealth();
    if (!health.ready) {
      return json(res, 502, { error: 'agent-provider-error' });
    }

    const today = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh',
      year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date());

    const selected = routeAgents(context.prompt);
    const specialistReports = await Promise.all(selected.map(async (id) => {
      try {
        return await runSpecialist(id, context, today);
      } catch (error) {
        const code = String(error?.message || error?.name || 'unknown').slice(0, 160);
        console.error('NeoTask specialist failed', { agent: id, code });
        return {
          id,
          name: AGENTS[id].nameAr,
          status: 'failed',
          report: 'تعذر تشغيل هذا الوكيل بالذكاء الاصطناعي في هذه المحاولة.',
          requestId: null,
        };
      }
    }));

    const completed = specialistReports.filter((item) => item.status === 'completed-ai');
    if (completed.length === 0) {
      return json(res, 502, { error: 'agent-provider-error' });
    }

    const executive = await runExecutive({ context, user, specialistReports, today });
    const deterministic = deterministicAction(context, today);
    const action = deterministic || validateAction(executive.action, context, today);

    const delegatedAgents = [
      { id: 'executive', name: AGENTS.executive.nameAr, status: 'completed-ai' },
      ...specialistReports.map(({ id, name, status }) => ({ id, name, status })),
    ];

    const truthStatus = action ? 'proposal' : 'analysis';
    const truthNote = action
      ? 'الإجراء مقترح ولم يُنفذ بعد؛ يحتاج اعتماد المدير داخل NeoTask.'
      : 'النتيجة تحليل بالذكاء الاصطناعي مبني على بيانات NeoTask المرسلة في هذا الطلب.';

    return json(res, 200, {
      reply: executive.reply,
      action,
      delegatedAgents,
      requestId: executive.requestId,
      mode: 'multi-agent-ai',
      provider: 'ai-gateway',
      model: MODEL,
      truthStatus,
      truthNote,
    });
  } catch (error) {
    const raw = String(error?.message || 'internal');
    const known = new Set([
      'manager-only',
      'rate-limit',
      'missing-token',
      'invalid-token',
      'profile-unavailable',
      'token-verification-unavailable',
      'invalid-message',
    ]);
    const code = known.has(raw) ? raw : 'internal';
    const status = code === 'manager-only' ? 403
      : code === 'rate-limit' ? 429
      : ['missing-token', 'invalid-token'].includes(code) ? 401
      : code === 'profile-unavailable' ? 403
      : code === 'token-verification-unavailable' ? 503
      : code === 'invalid-message' ? 400
      : 500;
    if (status >= 500) console.error('NeoTask multi-agent AI error', { code: raw.slice(0, 240) });
    return json(res, status, { error: code });
  }
}
