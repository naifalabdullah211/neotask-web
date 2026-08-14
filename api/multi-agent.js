import crypto from 'node:crypto';

const FIREBASE_PROJECT_ID = 'neotask1-ff5a4';
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const GATEWAY_BASE_URL = 'https://ai-gateway.vercel.sh/v1';
const GATEWAY_MODEL = process.env.AI_GATEWAY_MODEL || 'openai/gpt-5.6-sol';
const ALLOWED_ORIGINS = new Set([
  'https://neotask1-ff5a4.web.app',
  'https://neotask1-ff5a4.firebaseapp.com',
  'http://localhost:5000',
  'http://localhost:3000',
]);

const AGENTS = Object.freeze({
  executive: {
    id: 'executive',
    name: 'Executive Agent',
    nameAr: 'الوكيل التنفيذي',
    mission: 'ينسّق بقية الوكلاء، يجمع النتائج، ويحوّل طلب المدير إلى قرار أو إجراء قابل للاعتماد.',
  },
  tasks: {
    id: 'tasks',
    name: 'Task Agent',
    nameAr: 'وكيل المهام',
    mission: 'يتابع المهام والتأخير والأولويات والتوزيع والاستحقاقات ويقترح إجراءات تشغيلية دقيقة.',
  },
  projects: {
    id: 'projects',
    name: 'Projects Agent',
    nameAr: 'وكيل المشاريع',
    mission: 'يتابع الأهداف والمبادرات والمعايير ونسب الإنجاز والمخاطر الزمنية وخطط العمل.',
  },
  employees: {
    id: 'employees',
    name: 'Employees Agent',
    nameAr: 'وكيل الموظفين',
    mission: 'يحلل حمل الموظفين والسعة الأسبوعية والتوزيع والإنجاز ومؤشرات الأداء التشغيلية.',
  },
  meetings: {
    id: 'meetings',
    name: 'Meetings Agent',
    nameAr: 'وكيل الاجتماعات',
    mission: 'يراجع الاجتماعات والمحاضر والقرارات والمسؤولين والمواعيد والقرارات غير المرتبطة بمهام.',
  },
  knowledge: {
    id: 'knowledge',
    name: 'Knowledge Agent',
    nameAr: 'وكيل المعرفة',
    mission: 'يبحث في السياسات والإجراءات والأدلة وصفحات المعرفة ويجيب من المحتوى المتاح فقط.',
  },
  analytics: {
    id: 'analytics',
    name: 'Analytics Agent',
    nameAr: 'وكيل التحليلات',
    mission: 'يحوّل بيانات NeoTask إلى مؤشرات واتجاهات ومقارنات وأسباب محتملة مع فصل الحقائق عن الاستنتاجات.',
  },
  quality: {
    id: 'quality',
    name: 'Quality Agent',
    nameAr: 'وكيل الجودة',
    mission: 'يراقب فجوات الالتزام والتأخير والمعايير والمراجعات والوثائق ويقترح إجراءات تصحيحية.',
  },
});

const requestWindows = new Map();
let firebaseCertCache = {certs: null, expiresAt: 0};

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

function normalizeCredential(value) {
  return String(value || '').replace(/\s+/g, '');
}

function gatewayCredential(env = process.env) {
  return normalizeCredential(env.VERCEL_OIDC_TOKEN) ||
    normalizeCredential(env.AI_GATEWAY_API_KEY);
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
    !subject ||
    subject.length > 128 ||
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
  const windowMs = 60_000;
  const active = (requestWindows.get(uid) || []).filter((time) => now - time < windowMs);
  if (active.length >= 10) throw new Error('rate-limit');
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
    rules: list(body.agentRules, 20).map((item) => String(item || '').slice(0, 500)),
    truthMode: body.truthMode === true,
  };
}

function routeAgents(prompt) {
  const p = normalizeText(prompt);
  const broad = /(تقرير شامل|الوضع العام|وضع القسم|حلل القسم|كل شيء|كل شي|نظره شامله|نظرة شاملة)/.test(p);
  if (broad) {
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

async function callGateway(credential, instructions, input, maxOutputTokens = 900) {
  const response = await fetch(`${GATEWAY_BASE_URL}/responses`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${credential}`,
      'Content-Type': 'application/json',
    },
    signal: AbortSignal.timeout(25_000),
    body: JSON.stringify({
      model: GATEWAY_MODEL,
      instructions,
      input,
      max_output_tokens: maxOutputTokens,
    }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`gateway-${response.status}`);
  let text = body.output_text || '';
  if (!text) {
    for (const item of body.output || []) {
      if (item.type !== 'message') continue;
      for (const part of item.content || []) {
        if (part.type === 'output_text' && typeof part.text === 'string') text += part.text;
      }
    }
  }
  return {text: text.trim(), requestId: body.id || null};
}

async function runSpecialist(id, credential, context, user, today) {
  const agent = AGENTS[id];
  const truth = 'TruthMode: افصل الحقائق المستخرجة من NeoTask عن الاستنتاجات. لا تدّعِ تنفيذ أي تغيير. إذا لم توجد بيانات كافية فقل غير متحقق.';
  const instructions = `أنت ${agent.nameAr} داخل NeoTask. ${agent.mission}\n${truth}\nالتاريخ في السعودية: ${today}. أجب بنقاط عملية قصيرة للوكيل التنفيذي، دون مخاطبة المدير مباشرة.`;
  const input = [{
    role: 'user',
    content: `طلب المدير: ${context.prompt}\nبيانات نطاقك: ${JSON.stringify(agentContext(id, context))}`,
  }];
  const result = await callGateway(credential, instructions, input, 700);
  return {id, name: agent.nameAr, status: 'completed', report: result.text};
}

function fallbackSpecialist(id, context) {
  const agent = AGENTS[id];
  const tasks = context.tasks;
  const projects = context.projects;
  const meetings = context.meetings;
  const knowledge = context.knowledge;
  let report = 'لا توجد بيانات كافية للتحليل.';
  if (id === 'tasks') {
    const overdue = tasks.filter((item) => item.isOverdue).length;
    const active = tasks.filter((item) => item.status !== 'approved').length;
    report = `الحقائق: ${tasks.length} مهمة فريق، ${active} غير مكتملة، ${overdue} متأخرة.`;
  } else if (id === 'projects') {
    const criteria = projects.reduce((sum, item) => sum + Number(item.criteriaTotal || 0), 0);
    const completed = projects.reduce((sum, item) => sum + Number(item.criteriaCompleted || 0), 0);
    report = `الحقائق: ${projects.length} هدف/مشروع، ${criteria} معيارًا، ${completed} معيارًا مكتملًا.`;
  } else if (id === 'employees') {
    const busiest = [...context.team].sort((a, b) => Number(b.plannedHours || 0) - Number(a.plannedHours || 0))[0];
    report = `الحقائق: ${context.team.length} موظفًا نشطًا.` + (busiest ? ` أعلى حمل مخطط لدى ${busiest.name}: ${Number(busiest.plannedHours || 0).toFixed(1)} ساعة.` : '');
  } else if (id === 'meetings') {
    const openDecisions = meetings.reduce((sum, meeting) => sum + list(meeting.decisions, 100).filter((decision) => !decision.isCompleted).length, 0);
    report = `الحقائق: ${meetings.length} اجتماعًا في السياق، ${openDecisions} قرارًا غير مكتمل.`;
  } else if (id === 'knowledge') {
    const approved = knowledge.filter((item) => item.status === 'approved').length;
    const inReview = knowledge.filter((item) => item.status === 'inReview').length;
    report = `الحقائق: ${knowledge.length} عنصر معرفة، ${approved} معتمد، ${inReview} تحت المراجعة.`;
  } else if (id === 'analytics') {
    const overdue = tasks.filter((item) => item.isOverdue).length;
    report = `الحقائق: ${context.team.length} موظفًا، ${tasks.length} مهمة، ${projects.length} هدفًا، ${meetings.length} اجتماعًا، ${overdue} مهمة متأخرة.`;
  } else if (id === 'quality') {
    const q = context.quality || {};
    report = `الحقائق: مهام متأخرة ${Number(q.overdueTasks || 0)}، معايير لم تبدأ ${Number(q.criteriaNotStarted || 0)}، مراجعات وثائق متأخرة ${Number(q.documentReviewsOverdue || 0)}.`;
  }
  return {id, name: agent.nameAr, status: 'completed-local', report};
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
      reply: 'تم تجهيز القاعدة كمسودة وتنتظر اعتمادك؛ لم تُحفظ بعد.',
      action: {
        type: 'update_agent_rule', title: 'قاعدة دائمة للوكيل', payload: context.prompt,
        employeeUid: '', employeeNumber: '', employeeName: '', dueDate: '',
        priority: 'medium', plannedHours: 1, category: 'عام', requiresApproval: true,
      },
    };
  }
  const wantsTask = /(مهمه|مهمة|كلف|اسند|إسناد)/.test(p);
  const wantsInitiative = /(مبادره|مبادرة|فكره|فكرة)/.test(p);
  if (wantsTask || wantsInitiative) {
    const employee = matchEmployee(context.prompt, context.team);
    if (!employee) return {reply: 'حدد اسم الموظف أو رقمه الوظيفي قبل تجهيز الإجراء.', action: null};
    const dueDate = requestedDueDate(context.prompt, today);
    if (!dueDate) return {reply: `حدد موعد الاستحقاق لـ ${employee.name} قبل تجهيز الإجراء.`, action: null};
    return {
      reply: `تم تجهيز ${wantsInitiative ? 'المبادرة' : 'المهمة'} كمسودة لـ ${employee.name}. لم تُنشأ بعد؛ اعتمادك هو الذي ينفذها.`,
      action: {
        type: wantsInitiative ? 'create_initiative' : 'create_task_draft',
        title: context.prompt.slice(0, 160), payload: context.prompt.slice(0, 3000),
        employeeUid: employee.uid, employeeNumber: employee.employeeNumber,
        employeeName: employee.name, dueDate,
        priority: /(عاجل|ضروري|عاليه|عالية)/.test(p) ? 'high' : 'medium',
        plannedHours: 1, category: 'عام', requiresApproval: true,
      },
    };
  }
  return null;
}

function parseExecutive(text) {
  const cleaned = String(text || '').trim().replace(/^```json\s*/i, '').replace(/\s*```$/, '');
  try {
    const parsed = JSON.parse(cleaned);
    const action = parsed.action && typeof parsed.action === 'object'
      ? {
          type: String(parsed.action.type || ''),
          title: String(parsed.action.title || '').slice(0, 160),
          payload: String(parsed.action.payload || '').slice(0, 3000),
          employeeUid: String(parsed.action.employeeUid || '').slice(0, 128),
          employeeNumber: String(parsed.action.employeeNumber || '').slice(0, 40),
          employeeName: String(parsed.action.employeeName || '').slice(0, 120),
          dueDate: String(parsed.action.dueDate || '').slice(0, 10),
          priority: ['low', 'medium', 'high'].includes(parsed.action.priority) ? parsed.action.priority : 'medium',
          plannedHours: Math.min(168, Math.max(0.25, Number(parsed.action.plannedHours) || 1)),
          category: String(parsed.action.category || 'عام').slice(0, 80),
          requiresApproval: true,
        }
      : null;
    return {reply: String(parsed.reply || 'تم تحليل طلبك.').slice(0, 4000), action};
  } catch {
    return {reply: String(text || '').slice(0, 4000), action: null};
  }
}

export default async function handler(req, res) {
  setCors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method === 'GET') {
    return json(res, 200, {
      status: 'ready',
      agents: Object.values(AGENTS).map(({id, nameAr}) => ({id, name: nameAr})),
      count: 8,
      provider: gatewayCredential() ? 'ai-gateway' : 'resilient-local',
    });
  }
  if (req.method !== 'POST') return json(res, 405, {error: 'method-not-allowed'});

  try {
    const token = bearerToken(req);
    const identity = await verifyFirebaseIdentity(token);
    const user = await loadNeoTaskUser(token, identity.uid);
    enforceManager(user);
    enforceRateLimit(user.uid);

    const context = sanitizeBody(req.body || {});
    if (!context.prompt) return json(res, 400, {error: 'invalid-message'});
    const today = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date());
    const selected = routeAgents(context.prompt);
    const credential = gatewayCredential();

    let specialistReports;
    let mode = 'resilient-local';
    if (credential) {
      const attempts = await Promise.all(selected.map(async (id) => {
        try {
          return await runSpecialist(id, credential, context, user, today);
        } catch {
          return fallbackSpecialist(id, context);
        }
      }));
      specialistReports = attempts;
      if (attempts.some((item) => item.status === 'completed')) mode = 'multi-agent';
    } else {
      specialistReports = selected.map((id) => fallbackSpecialist(id, context));
    }

    const deterministic = deterministicAction(context, today);
    let finalResult = deterministic;
    let requestId = null;

    if (!finalResult && credential) {
      try {
        const executiveInstructions = `أنت ${AGENTS.executive.nameAr} داخل NeoTask. ${AGENTS.executive.mission}\nTruthMode إلزامي: لا تقل تم التنفيذ إلا إذا كان لديك دليل تنفيذ فعلي من NeoTask. تقارير الوكلاء أدناه تحليل فقط.\nإذا كان الطلب يحتاج إجراءً، أعد JSON فقط: {"reply":"...","action":{"type":"create_task_draft|create_initiative|update_agent_rule|team_summary","title":"...","payload":"...","employeeUid":"","employeeNumber":"","employeeName":"","dueDate":"YYYY-MM-DD","priority":"low|medium|high","plannedHours":1,"category":"عام"}}. وإلا أعد {"reply":"...","action":null}.`;
        const executiveInput = [{
          role: 'user',
          content: `اسم المدير: ${user.name || 'المدير'}\nطلب المدير: ${context.prompt}\nقواعد المدير: ${JSON.stringify(context.rules)}\nتقارير الوكلاء المتخصصين: ${JSON.stringify(specialistReports)}`,
        }];
        const executive = await callGateway(credential, executiveInstructions, executiveInput, 1200);
        finalResult = parseExecutive(executive.text);
        requestId = executive.requestId;
      } catch {
        finalResult = null;
      }
    }

    if (!finalResult) {
      const combined = specialistReports.map((item) => `• ${item.name}: ${item.report}`).join('\n');
      finalResult = {
        reply: combined || 'لا توجد بيانات كافية للتحليل.',
        action: null,
      };
    }

    const delegatedAgents = [
      {id: 'executive', name: AGENTS.executive.nameAr, status: 'completed'},
      ...specialistReports.map(({id, name, status}) => ({id, name, status})),
    ];

    return json(res, 200, {
      ...finalResult,
      delegatedAgents,
      requestId,
      mode,
    });
  } catch (error) {
    const raw = error?.message || '';
    const known = new Set([
      'manager-only', 'rate-limit', 'missing-token', 'invalid-token',
      'profile-unavailable', 'token-verification-unavailable',
    ]);
    const code = known.has(raw) ? raw : 'internal';
    const status = code === 'manager-only' ? 403
      : code === 'rate-limit' ? 429
      : ['missing-token', 'invalid-token'].includes(code) ? 401
      : code === 'profile-unavailable' ? 403
      : code === 'token-verification-unavailable' ? 503
      : 500;
    if (status >= 500) console.error('NeoTask multi-agent error', {code});
    return json(res, status, {error: code});
  }
}
