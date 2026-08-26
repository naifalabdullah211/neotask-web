/**
 * NeoTask Cloud Functions (neotask1-ff5a4)
 *
 * ------------------------------------------------------------------------
 * Optional Blaze-plan helpers. NeoTask's Spark-plan production workflow does
 * not deploy this directory; core authentication, first-manager setup,
 * Firestore Rules, and Hosting do not depend on these functions.
 * ------------------------------------------------------------------------
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  enforceRateLimit,
  normalizeEmployeeNumber,
  requirePlainText,
} = require("./security");

admin.initializeApp();

const db = admin.firestore();
const FULL_ACCESS_EMPLOYEE_NUMBER = "400161";

function hasManagerAccess(user) {
  return Boolean(user) && user.accountStatus === "active" &&
    (user.role === "manager" ||
     String(user.employeeNumber || "").trim() === FULL_ACCESS_EMPLOYEE_NUMBER);
}

async function requireActiveManager(auth) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }
  const snapshot = await db.collection("users").doc(auth.uid).get();
  const user = snapshot.data();
  if (!snapshot.exists || !hasManagerAccess(user)) {
    throw new HttpsError("permission-denied", "هذه العملية متاحة للمدير فقط");
  }
  return user;
}

function callerIdentifier(request) {
  if (request.auth && request.auth.uid) return `uid:${request.auth.uid}`;
  const rawRequest = request.rawRequest;
  const address = rawRequest &&
    (rawRequest.ip || (rawRequest.socket && rawRequest.socket.remoteAddress));
  return `ip:${address || "unknown"}`;
}

async function requireRateLimit(request, scope, {limit, windowMs}) {
  const result = await enforceRateLimit({
    db,
    scope,
    identifier: callerIdentifier(request),
    limit,
    windowMs,
  });
  if (!result.allowed) {
    throw new HttpsError(
        "resource-exhausted",
        "محاولات كثيرة، انتظر قليلًا ثم أعد المحاولة",
    );
  }
}

/**
 * adminResetPassword — manager-driven password change for ANOTHER user.
 *
 * A regular Firebase Auth client SDK can only change the CURRENTLY signed-
 * in user's own password (via reauthenticate + updatePassword). Changing
 * a DIFFERENT user's password requires the Admin SDK's
 * `admin.auth().updateUser(uid, { password })`, which only privileged
 * server-side code (this Cloud Function) may call.
 *
 * Request data: { userId: string, newPassword: string }
 *
 * Authorization (server-side, NEVER trust the client's own role claim):
 *   1. Caller must be authenticated (`request.auth` present).
 *   2. Caller's Firestore `users/{callerUid}` document must have
 *      `role == "manager"` AND `accountStatus == "active"`.
 *      (This project has no custom-claims mechanism yet, so role is
 *      looked up directly in Firestore — acceptable per the original
 *      requirement, which explicitly allows "custom claims OR Firestore
 *      lookup, either acceptable".)
 *
 * The password value itself is NEVER logged, returned, or written to
 * Firestore by this function — only the Flutter client writes the
 * (password-free) audit entry to `password_change_audit` after this call
 * succeeds (see `FirestoreService.logPasswordChange` /
 * `manager_employees_tab.dart._startChangePasswordFlow`).
 */
exports.adminResetPassword = onCall(async (request) => {
  const {auth, data} = request;

  // 1) Must be authenticated.
  if (!auth) {
    throw new HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول لتنفيذ هذا الإجراء",
    );
  }

  await requireActiveManager(auth);
  await requireRateLimit(request, "admin_reset_password", {
    limit: 10,
    windowMs: 10 * 60 * 1000,
  });

  const {userId, newPassword} = data || {};

  // 2) Basic input validation.
  if (typeof userId !== "string" || userId.trim().length === 0 ||
      userId.length > 128) {
    throw new HttpsError(
        "invalid-argument",
        "معرّف المستخدم المستهدف غير صالح",
    );
  }
  if (typeof newPassword !== "string" || newPassword.length < 6 ||
      newPassword.length > 128) {
    throw new HttpsError(
        "invalid-argument",
        "كلمة المرور الجديدة يجب أن تتكون من 6 أحرف على الأقل",
    );
  }

  // 3) Target user must exist.
  const targetSnap = await db.collection("users").doc(userId).get();
  if (!targetSnap.exists) {
    throw new HttpsError(
        "not-found",
        "المستخدم المستهدف غير موجود",
    );
  }

  // 4) Perform the privileged password update via the Admin SDK.
  try {
    await admin.auth().updateUser(userId, {password: newPassword});
  } catch (err) {
    if (err && err.code === "auth/user-not-found") {
      throw new HttpsError(
          "not-found",
          "حساب المصادقة لهذا المستخدم غير موجود",
      );
    }
    console.error("Password reset failed", {
      code: err && err.code ? err.code : "unknown",
    });
    throw new HttpsError("internal", "تعذّر تغيير كلمة المرور");
  }

  return {success: true};
});

/**
 * Creates real employee accounts from the validated CSV/XLSX preview.
 * Each row is isolated: a duplicate or invalid row is returned as failed
 * without rolling back successfully-created accounts from other rows.
 */
exports.bulkImportEmployees = onCall(async (request) => {
  const manager = await requireActiveManager(request.auth);
  await requireRateLimit(request, "bulk_import_employees", {
    limit: 3,
    windowMs: 15 * 60 * 1000,
  });
  const rows = request.data && request.data.employees;
  if (!Array.isArray(rows) || rows.length === 0 || rows.length > 200) {
    throw new HttpsError(
        "invalid-argument",
        "يجب إرسال قائمة من 1 إلى 200 موظف",
    );
  }

  const results = [];
  const seen = new Set();
  for (let index = 0; index < rows.length; index++) {
    const row = rows[index] || {};
    let name;
    let employee;
    try {
      name = requirePlainText(row.name, "name", {
        minLength: 2,
        maxLength: 120,
      });
      employee = normalizeEmployeeNumber(row.employeeNumber);
    } catch (_) {
      results.push({index, success: false, error: "بيانات الصف غير صالحة"});
      continue;
    }
    const employeeNumber = employee.display;
    const password = typeof row.password === "string" ? row.password : "";
    const compact = employee.compact;
    if (password.length < 6 || password.length > 128) {
      results.push({index, success: false, error: "بيانات الصف غير مكتملة"});
      continue;
    }
    if (seen.has(compact)) {
      results.push({index, success: false, error: "رقم وظيفي مكرر"});
      continue;
    }
    seen.add(compact);

    let authUser;
    try {
      const email = `${compact}@neotask.local`;
      authUser = await admin.auth().createUser({email, password});
      const now = new Date().toISOString();
      await db.collection("users").doc(authUser.uid).set({
        uid: authUser.uid,
        name,
        email,
        employeeNumber,
        role: "employee",
        accountStatus: "active",
        approvedBy: request.auth.uid,
        approvedAt: now,
        createdAt: now,
        soundMessagesEnabled: true,
        soundTasksEnabled: true,
        remindersEnabled: true,
        weeklyCapacityHours: 40,
      });
      results.push({index, success: true, uid: authUser.uid});
    } catch (error) {
      if (authUser) {
        await admin.auth().deleteUser(authUser.uid).catch(() => null);
      }
      const duplicate = error && error.code === "auth/email-already-exists";
      results.push({
        index,
        success: false,
        error: duplicate ? "الرقم الوظيفي موجود مسبقًا" : "تعذر إنشاء الحساب",
      });
    }
  }

  const createdCount = results.filter((result) => result.success).length;
  const jobRef = db.collection("import_jobs").doc();
  await jobRef.set({
    jobId: jobRef.id,
    type: "employees",
    rowCount: rows.length,
    createdCount,
    failedCount: rows.length - createdCount,
    createdBy: request.auth.uid,
    createdByName: manager.name || "",
    createdAt: new Date().toISOString(),
    status: "completed",
  });
  return {
    createdCount,
    failedCount: rows.length - createdCount,
    results,
  };
});

function taskField(task, field) {
  switch (field) {
    case "status": return task.status || "";
    case "priority": return task.priority || "";
    case "category": return task.category || "";
    case "assignee": return task.assignedTo || "";
    case "progress": return Number(task.progressPercent || 0);
    default: return "";
  }
}

function conditionMatches(rule, task) {
  if (!rule.conditionField || rule.conditionField === "any") return true;
  const actual = taskField(task, rule.conditionField);
  const expected = rule.conditionValue || "";
  if (rule.conditionOperator === "contains") {
    return String(actual).toLowerCase().includes(String(expected).toLowerCase());
  }
  if (rule.conditionOperator === "greaterOrEqual") {
    return Number(actual) >= Number(expected);
  }
  return String(actual).toLowerCase() === String(expected).toLowerCase();
}

function temporalTriggerMatches(rule, task, now) {
  const due = new Date(task.dueDate);
  if (Number.isNaN(due.getTime()) || task.status === "approved") return false;
  const hours = (due.getTime() - now.getTime()) / 3600000;
  if (rule.trigger === "overdue") return hours < 0;
  if (rule.trigger === "dueSoon") {
    const threshold = Number(rule.dueWithinHours || 24);
    return hours >= 0 && hours <= threshold;
  }
  return true;
}

async function notificationRecipients(rule, task) {
  if (rule.action === "notifyAssignee") return [task.assignedTo];
  const managers = await db.collection("users")
      .where("accountStatus", "==", "active")
      .get();
  return managers.docs
      .filter((doc) => hasManagerAccess(doc.data()))
      .map((doc) => doc.id);
}

function addAutomationHistory(batch, rule, taskId, note) {
  const ref = db.collection("task_history").doc();
  batch.set(ref, {
    historyId: ref.id,
    taskId,
    action: "statusChange",
    actorUid: rule.createdBy,
    note,
    timestamp: new Date().toISOString(),
  });
}

async function executeAutomationAction(rule, task, taskId) {
  if (rule.action === "notifyAssignee" || rule.action === "notifyManager") {
    const recipients = await notificationRecipients(rule, task);
    const batch = db.batch();
    for (const recipientUid of recipients.filter(Boolean)) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        notificationId: ref.id,
        recipientUid,
        type: "automation",
        title: `أتمتة: ${rule.name}`,
        body: rule.actionValue || `تم تشغيل قاعدة على المهمة: ${task.title}`,
        relatedPollId: null,
        relatedTaskId: taskId,
        payload: {ruleId: rule.ruleId},
        createdAt: new Date().toISOString(),
        readAt: null,
      });
    }
    await batch.commit();
    return;
  }
  if (rule.action === "setPriority") {
    if (!["low", "medium", "high"].includes(rule.actionValue)) {
      throw new Error("قيمة الأولوية غير صالحة");
    }
    const batch = db.batch();
    batch.update(db.collection("tasks").doc(taskId), {
      priority: rule.actionValue,
      updatedAt: new Date().toISOString(),
    });
    addAutomationHistory(
        batch,
        rule,
        taskId,
        `الأتمتة «${rule.name}» غيّرت أولوية المهمة`,
    );
    await batch.commit();
    return;
  }
  if (rule.action === "reassign") {
    const target = await db.collection("users").doc(rule.actionValue).get();
    const user = target.data();
    if (!target.exists || !user || user.role !== "employee" ||
        user.accountStatus !== "active") {
      throw new Error("الموظف المستهدف غير متاح");
    }
    const batch = db.batch();
    batch.update(db.collection("tasks").doc(taskId), {
      assignedTo: target.id,
      viewedByEmployee: false,
      updatedAt: new Date().toISOString(),
    });
    addAutomationHistory(
        batch,
        rule,
        taskId,
        `الأتمتة «${rule.name}» أعادت إسناد المهمة`,
    );
    await batch.commit();
  }
}

async function reserveAndExecute(
    rule,
    task,
    taskId,
    eventKey,
    {trigger, source},
) {
  const safeKey = `${rule.ruleId}_${taskId}_${eventKey}`
      .replace(/[^a-zA-Z0-9_-]/g, "_");
  const runRef = db.collection("automation_runs").doc(safeKey);
  const startedAt = new Date();
  const reserved = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(runRef);
    if (existing.exists) return false;
    transaction.set(runRef, {
      runId: safeKey,
      ruleId: rule.ruleId,
      ruleName: rule.name,
      taskId,
      taskTitle: task.title || "",
      action: rule.action,
      trigger,
      source,
      status: "running",
      executedAt: startedAt.toISOString(),
      startedAt: startedAt.toISOString(),
    });
    return true;
  });
  if (!reserved) return;
  try {
    await executeAutomationAction(rule, task, taskId);
    const completedAt = new Date();
    await runRef.update({
      status: "completed",
      completedAt: completedAt.toISOString(),
      durationMs: completedAt.getTime() - startedAt.getTime(),
    });
  } catch (error) {
    const completedAt = new Date();
    await runRef.update({
      status: "failed",
      message: error && error.message ? error.message : "فشل التنفيذ",
      completedAt: completedAt.toISOString(),
      durationMs: completedAt.getTime() - startedAt.getTime(),
    });
  }
}

async function processRules({task, taskId, trigger, eventKey, now, source}) {
  const snapshot = await db.collection("automation_rules")
      .where("isActive", "==", true)
      .get();
  for (const doc of snapshot.docs) {
    const rule = doc.data();
    if (rule.trigger !== trigger) continue;
    if (!conditionMatches(rule, task)) continue;
    if (!temporalTriggerMatches(rule, task, now)) continue;
    await reserveAndExecute(rule, task, taskId, eventKey, {trigger, source});
  }
}

async function processKnowledgeReviewReminders(now) {
  const [documents, activeUsers] = await Promise.all([
    db.collection("documents").where("status", "==", "approved").get(),
    db.collection("users").where("accountStatus", "==", "active").get(),
  ]);
  const managerUids = activeUsers.docs
      .filter((doc) => hasManagerAccess(doc.data()))
      .map((doc) => doc.id);
  for (const documentDoc of documents.docs) {
    const document = documentDoc.data();
    if (!document.reviewDueDate ||
        document.reviewReminderForDate === document.reviewDueDate) continue;
    const due = new Date(document.reviewDueDate);
    if (Number.isNaN(due.getTime()) ||
        (due.getTime() - now.getTime()) / 86400000 > 7) continue;

    const recipients = new Set(managerUids);
    if (document.ownerUid) recipients.add(document.ownerUid);
    const batch = db.batch();
    for (const recipientUid of recipients) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        notificationId: ref.id,
        recipientUid,
        type: "knowledgeReviewDue",
        title: due < now ? "تأخرت مراجعة وثيقة" : "اقترب موعد مراجعة وثيقة",
        body: `الوثيقة «${document.title || "بدون عنوان"}» موعد مراجعتها ${String(document.reviewDueDate).slice(0, 10)}`,
        relatedPollId: null,
        relatedTaskId: null,
        relatedDocumentId: documentDoc.id,
        payload: {reviewDueDate: document.reviewDueDate},
        createdAt: now.toISOString(),
        readAt: null,
      });
    }
    batch.update(documentDoc.ref, {
      reviewReminderSentAt: now.toISOString(),
      reviewReminderForDate: document.reviewDueDate,
    });
    await batch.commit();
  }
}

exports.runAutomationsOnTaskCreated = onDocumentCreated(
    "tasks/{taskId}",
    async (event) => {
      const task = event.data && event.data.data();
      if (!task) return;
      await processRules({
        task,
        taskId: event.params.taskId,
        trigger: "taskCreated",
        eventKey: event.id,
        now: new Date(),
        source: "firestore-event",
      });
    },
);

exports.runAutomationsOnTaskStatusChanged = onDocumentUpdated(
    "tasks/{taskId}",
    async (event) => {
      if (!event.data) return;
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (before.status === after.status) return;
      await processRules({
        task: after,
        taskId: event.params.taskId,
        trigger: "statusChanged",
        eventKey: event.id,
        now: new Date(),
        source: "firestore-event",
      });
    },
);

exports.runScheduledAutomations = onSchedule(
    {schedule: "every 60 minutes", timeZone: "Asia/Riyadh"},
    async () => {
      const now = new Date();
      const tasks = await db.collection("tasks").get();
      for (const doc of tasks.docs) {
        const task = doc.data();
        await processRules({
          task,
          taskId: doc.id,
          trigger: "dueSoon",
          eventKey: `dueSoon_${task.dueDate}`,
          now,
          source: "cloud-scheduler",
        });
        await processRules({
          task,
          taskId: doc.id,
          trigger: "overdue",
          eventKey: `overdue_${task.dueDate}`,
          now,
          source: "cloud-scheduler",
        });
      }
      await processKnowledgeReviewReminders(now);
    },
);
