from pathlib import Path
import re

path = Path('api/openai-agent.js')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        if new in text:
            return
        raise SystemExit(f'missing patch target: {label}')
    text = text.replace(old, new, 1)


def regex_once(pattern: str, replacement: str, label: str) -> None:
    global text
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count == 0:
        if replacement in text:
            return
        raise SystemExit(f'missing regex target: {label}')
    text = updated


replace_once(
    "});\n\nconst requestWindows = new Map();",
    """});

const AGENT_EN = Object.freeze({
  executive: {name: 'Executive Agent', mission: 'Coordinates specialist agents and consolidates their findings for the manager.'},
  tasks: {name: 'Tasks Agent', mission: 'Analyzes tasks, overdue work, due dates, priorities, and assignment distribution.'},
  projects: {name: 'Projects Agent', mission: 'Analyzes goals, initiatives, criteria, completion rates, and schedule risks.'},
  employees: {name: 'Employees Agent', mission: 'Analyzes employee workload, weekly capacity, distribution, and operational performance.'},
  meetings: {name: 'Meetings Agent', mission: 'Reviews meetings, minutes, decisions, owners, and due dates.'},
  knowledge: {name: 'Knowledge Agent', mission: 'Searches only NeoTask policies, procedures, guides, and knowledge pages available in context.'},
  analytics: {name: 'Analytics Agent', mission: 'Turns NeoTask data into specific metrics, trends, comparisons, and grounded conclusions.'},
  quality: {name: 'Quality Agent', mission: 'Reviews compliance gaps, delays, criteria, document reviews, and proposes corrective actions.'},
});

function agentName(id, languageCode = 'ar') {
  return languageCode === 'en' ? AGENT_EN[id]?.name || id : AGENTS[id]?.name || id;
}

function agentMission(id, languageCode = 'ar') {
  return languageCode === 'en' ? AGENT_EN[id]?.mission || '' : AGENTS[id]?.mission || '';
}

const requestWindows = new Map();""",
    'agent english metadata',
)

old_sanitize = """function sanitizeBody(body = {}) {
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
}"""
new_sanitize = old_sanitize.replace(
    "    prompt: String(body.message || '').trim().slice(0, 4000),",
    "    prompt: String(body.message || '').trim().slice(0, 4000),\n    languageCode: body.languageCode === 'en' ? 'en' : 'ar',",
)
replace_once(old_sanitize, new_sanitize, 'sanitize language code')

regex_once(
    r"function routeAgents\(prompt\) \{.*?\n\}\n\nfunction agentContext",
    """function routeAgents(prompt) {
  const p = normalizeText(prompt);
  if (/(تقرير شامل|الوضع العام|وضع القسم|حلل القسم|كل شيء|كل شي|نظره شامله|نظرة شاملة|comprehensive report|overall status|department status|analy[sz]e (?:the )?department|everything|full overview)/.test(p)) {
    return ['tasks', 'projects', 'employees', 'meetings', 'knowledge', 'analytics', 'quality'];
  }
  const selected = new Set();
  if (/(مهمه|مهمة|مهام|متاخر|استحقاق|توزيع|اسناد|إسناد|عاجل|task|tasks|overdue|due date|deadline|assign|assignment|urgent|priority)/.test(p)) selected.add('tasks');
  if (/(مشروع|مبادره|مبادرة|هدف|اهداف|أهداف|معيار|معايير|خطة عمل|خطه عمل|project|projects|initiative|initiatives|goal|goals|criterion|criteria|work plan)/.test(p)) selected.add('projects');
  if (/(موظف|موظفين|فريق|حمل|سعه|سعة|اداء موظف|أداء موظف|طاقه|طاقة|employee|employees|team|workload|capacity|staff performance)/.test(p)) selected.add('employees');
  if (/(اجتماع|اجتماعات|محضر|قرار اجتماع|قرارات الاجتماع|اجنده|أجندة|meeting|meetings|minutes|agenda|meeting decision)/.test(p)) selected.add('meetings');
  if (/(سياسه|سياسة|اجراء|إجراء|دليل|ملف|وثيقه|وثيقة|معرفه|معرفة|مركز المعرفة|policy|procedure|guide|document|file|knowledge|knowledge center)/.test(p)) selected.add('knowledge');
  if (/(تحليل|احصائ|إحصائ|مؤشر|مؤشرات|kpi|تقرير|اتجاه|مقارنه|مقارنة|analysis|analytics|metric|metrics|indicator|indicators|report|trend|comparison)/.test(p)) selected.add('analytics');
  if (/(جوده|جودة|التزام|تدقيق|فجوه|فجوة|تصحيحي|مراجعه|مراجعة|اعتماد|quality|compliance|audit|gap|corrective|review|accreditation)/.test(p)) selected.add('quality');
  if (selected.size === 0) selected.add('tasks');
  return [...selected];
}

function agentContext""",
    'bilingual agent routing',
)

regex_once(
    r"async function runSpecialist\(id, context, today\) \{.*?\n\}",
    """async function runSpecialist(id, context, today) {
  const languageCode = context.languageCode;
  const name = agentName(id, languageCode);
  const mission = agentMission(id, languageCode);
  const instructions = languageCode === 'en'
    ? `You are the ${name} inside NeoTask. ${mission}\nTruthMode is mandatory: separate NeoTask facts from inferences, never claim you executed a change, and never invent data. Saudi date: ${today}. Reply in concise English bullets for the Executive Agent.`
    : `أنت ${name} داخل NeoTask. ${mission}\nTruthMode إلزامي: افصل الحقائق من NeoTask عن الاستنتاجات. لا تدّعِ تنفيذ أي تغيير. لا تخترع بيانات. التاريخ في السعودية: ${today}. أجب بنقاط عربية قصيرة موجهة للوكيل التنفيذي.`;
  const input = languageCode === 'en'
    ? `Manager request: ${context.prompt}\nLive scope data: ${JSON.stringify(agentContext(id, context))}`
    : `طلب المدير: ${context.prompt}\nبيانات نطاقك الحية: ${JSON.stringify(agentContext(id, context))}`;
  const result = await openAiResponse({instructions, input, maxOutputTokens: 650});
  return {id, name, status: 'completed-ai', report: result.text};
}""",
    'specialist language',
)

regex_once(
    r"function requestedDueDate\(prompt, today\) \{.*?\n\}",
    """function requestedDueDate(prompt, today) {
  const p = normalizeText(prompt);
  const explicit = p.match(/\\b(20\\d{2}-\\d{2}-\\d{2})\\b/);
  if (explicit) return explicit[1];
  if (/(غدا|غد|بكره|بكرة|tomorrow)/.test(p)) return addDays(today, 1);
  const relativeAr = p.match(/بعد\\s+(\\d{1,3})\\s+(?:يوم|ايام)/);
  if (relativeAr) return addDays(today, Math.max(1, Number(relativeAr[1])));
  const relativeEn = p.match(/(?:after|in)\\s+(\\d{1,3})\\s+days?/);
  return relativeEn ? addDays(today, Math.max(1, Number(relativeEn[1]))) : '';
}""",
    'english due dates',
)

regex_once(
    r"function deterministicAction\(context, today\) \{.*?\n\}\n\nfunction parseExecutive",
    """function deterministicAction(context, today) {
  const p = normalizeText(context.prompt);
  const en = context.languageCode === 'en';
  if (/(قاعده|قاعدة|من الان|دائما|تذكر|rule|from now on|always|remember)/.test(p)) {
    return {
      reply: en
        ? 'I prepared the rule as a draft awaiting your approval; it has not been saved yet.'
        : 'جهزت القاعدة كمسودة وتنتظر اعتمادك؛ لم تُحفظ بعد.',
      action: {
        type: 'update_agent_rule',
        title: en ? 'Permanent agent rule' : 'قاعدة دائمة للوكيل',
        payload: context.prompt,
        employeeUid: '', employeeNumber: '', employeeName: '', dueDate: '',
        priority: 'medium', plannedHours: 1, category: en ? 'General' : 'عام', requiresApproval: true,
      },
    };
  }
  const wantsTask = /(مهمه|مهمة|كلف|اسند|إسناد|task|assign|delegate)/.test(p);
  const wantsInitiative = /(مبادره|مبادرة|فكره|فكرة|initiative|idea)/.test(p);
  if (!wantsTask && !wantsInitiative) return null;
  const employee = matchEmployee(context.prompt, context.team);
  if (!employee) {
    return {
      reply: en
        ? 'Specify the employee name or employee ID before I prepare the action.'
        : 'حدد اسم الموظف أو رقمه الوظيفي قبل تجهيز الإجراء.',
      action: null,
    };
  }
  const dueDate = requestedDueDate(context.prompt, today);
  if (!dueDate) {
    return {
      reply: en
        ? `Specify a due date for ${employee.name} before I prepare the action.`
        : `حدد موعد الاستحقاق لـ ${employee.name} قبل تجهيز الإجراء.`,
      action: null,
    };
  }
  return {
    reply: en
      ? `I prepared the ${wantsInitiative ? 'initiative' : 'task'} as a draft for ${employee.name}. It has not been created yet; your approval executes it.`
      : `جهزت ${wantsInitiative ? 'المبادرة' : 'المهمة'} كمسودة لـ ${employee.name}. لم تُنشأ بعد؛ اعتمادك هو الذي ينفذها.`,
    action: {
      type: wantsInitiative ? 'create_initiative' : 'create_task_draft',
      title: context.prompt.slice(0, 160),
      payload: context.prompt.slice(0, 3000),
      employeeUid: employee.uid,
      employeeNumber: employee.employeeNumber,
      employeeName: employee.name,
      dueDate,
      priority: /(عاجل|ضروري|عاليه|عالية|urgent|high priority|critical)/.test(p) ? 'high' : 'medium',
      plannedHours: 1,
      category: en ? 'General' : 'عام',
      requiresApproval: true,
    },
  };
}

function parseExecutive""",
    'deterministic bilingual replies',
)

regex_once(
    r"function parseExecutive\(text\) \{.*?\n\}\n\nasync function runExecutive",
    """function parseExecutive(text, languageCode = 'ar') {
  const cleaned = String(text || '').trim().replace(/^```json\\s*/i, '').replace(/\\s*```$/, '');
  const en = languageCode === 'en';
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
          category: String(rawAction.category || (en ? 'General' : 'عام')).slice(0, 80),
          requiresApproval: true,
        }
      : null;
    return {reply: String(parsed.reply || (en ? 'Your request was analyzed.' : 'تم تحليل طلبك.')).slice(0, 4000), action};
  } catch {
    return {reply: String(text || '').slice(0, 4000), action: null};
  }
}

async function runExecutive""",
    'executive parser language',
)

regex_once(
    r"async function runExecutive\(context, user, specialistReports, today\) \{.*?\n\}",
    """async function runExecutive(context, user, specialistReports, today) {
  const en = context.languageCode === 'en';
  const name = agentName('executive', context.languageCode);
  const mission = agentMission('executive', context.languageCode);
  const instructions = en
    ? `You are the ${name} inside NeoTask. ${mission}\nTruthMode is mandatory: never say an action was executed, saved, or sent unless there is actual NeoTask execution evidence. Specialist reports are analysis, not execution. Separate facts from inferences and never invent data. Saudi date: ${today}. Return JSON only in this shape {\"reply\":\"clear English reply\",\"action\":null}. Use action only when it can be presented for manager approval inside NeoTask.`
    : `أنت ${name} داخل NeoTask. ${mission}\nTruthMode إلزامي: لا تقل تم التنفيذ أو تم الحفظ أو تم الإرسال إلا إذا ورد دليل تنفيذ فعلي من NeoTask. تقارير الوكلاء تحليل وليست تنفيذًا. افصل الحقائق عن الاستنتاجات. لا تخترع أي بيانات. التاريخ في السعودية: ${today}. أعد JSON فقط بالشكل {\"reply\":\"رد عربي واضح\",\"action\":null}. استخدم action فقط إذا كان الإجراء قابلاً للاعتماد داخل NeoTask.`;
  const input = en
    ? `Manager name: ${user.name || 'Manager'}\nManager request: ${context.prompt}\nManager rules: ${JSON.stringify(context.rules)}\nSpecialist reports: ${JSON.stringify(specialistReports)}`
    : `اسم المدير: ${user.name || 'المدير'}\nطلب المدير: ${context.prompt}\nقواعد المدير: ${JSON.stringify(context.rules)}\nتقارير الوكلاء: ${JSON.stringify(specialistReports)}`;
  const result = await openAiResponse({instructions, input, maxOutputTokens: 1100});
  return {...parseExecutive(result.text, context.languageCode), requestId: result.requestId};
}""",
    'executive language',
)

replace_once(
    "agents: Object.values(AGENTS).map(({id, name}) => ({id, name})),",
    "agents: Object.values(AGENTS).map(({id}) => ({id, name: agentName(id, req.query?.lang === 'en' ? 'en' : 'ar')})),",
    'health localized agent names',
)

replace_once(
    "{id: 'executive', name: AGENTS.executive.name, status: 'completed-ai'},",
    "{id: 'executive', name: agentName('executive', context.languageCode), status: 'completed-ai'},",
    'localized executive delegation',
)

path.write_text(text, encoding='utf-8')
print('Patched NeoTask OpenAI agents for Arabic/English parity')
