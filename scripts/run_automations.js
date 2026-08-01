"use strict";

const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "neotask1-ff5a4",
});

const db = admin.firestore();

function taskField(task, field) {
  if (field === "status") return task.status || "";
  if (field === "priority") return task.priority || "";
  if (field === "category") return task.category || "";
  if (field === "assignee") return task.assignedTo || "";
  if (field === "progress") return Number(task.progressPercent || 0);
  return "";
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
    return hours >= 0 && hours <= Number(rule.dueWithinHours || 24);
  }
  return true;
}

async function recipientIds(rule, task) {
  if (rule.action === "notifyAssignee") return [task.assignedTo].filter(Boolean);
  const managers = await db.collection("users").where("role", "==", "manager").get();
  return managers.docs
      .filter((doc) => doc.data().accountStatus === "active")
      .map((doc) => doc.id);
}

function addHistory(batch, rule, taskId, note) {
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

async function executeAction(rule, task, taskId) {
  if (rule.action === "notifyAssignee" || rule.action === "notifyManager") {
    const batch = db.batch();
    for (const recipientUid of await recipientIds(rule, task)) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        notificationId: ref.id,
        recipientUid,
        type: "automation",
        title: `أتمتة: ${rule.name}`,
        body: rule.actionValue || `تم تشغيل قاعدة على المهمة: ${task.title || ""}`,
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
      throw new Error("Invalid priority action value");
    }
    const batch = db.batch();
    batch.update(db.collection("tasks").doc(taskId), {
      priority: rule.actionValue,
      updatedAt: new Date().toISOString(),
    });
    addHistory(batch, rule, taskId, `الأتمتة «${rule.name}» غيّرت أولوية المهمة`);
    await batch.commit();
    return;
  }
  if (rule.action === "reassign") {
    const target = await db.collection("users").doc(rule.actionValue).get();
    const user = target.data();
    if (!target.exists || !user || user.role !== "employee" || user.accountStatus !== "active") {
      throw new Error("Automation target employee is unavailable");
    }
    const batch = db.batch();
    batch.update(db.collection("tasks").doc(taskId), {
      assignedTo: target.id,
      viewedByEmployee: false,
      updatedAt: new Date().toISOString(),
    });
    addHistory(batch, rule, taskId, `الأتمتة «${rule.name}» أعادت إسناد المهمة`);
    await batch.commit();
  }
}

async function reserveAndExecute(rule, task, taskId, eventKey) {
  const runId = `${rule.ruleId}_${taskId}_${eventKey}`.replace(/[^a-zA-Z0-9_-]/g, "_");
  const runRef = db.collection("automation_runs").doc(runId);
  const reserved = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(runRef);
    if (existing.exists) return false;
    transaction.set(runRef, {
      runId,
      ruleId: rule.ruleId,
      ruleName: rule.name,
      taskId,
      taskTitle: task.title || "",
      action: rule.action,
      status: "running",
      executedAt: new Date().toISOString(),
    });
    return true;
  });
  if (!reserved) return;
  try {
    await executeAction(rule, task, taskId);
    await runRef.update({status: "completed"});
  } catch (error) {
    await runRef.update({status: "failed", message: error.message || "Execution failed"});
  }
}

async function processRules(rules, task, taskId, trigger, eventKey, now) {
  for (const rule of rules) {
    if (rule.trigger !== trigger) continue;
    if (!conditionMatches(rule, task)) continue;
    if (!temporalTriggerMatches(rule, task, now)) continue;
    await reserveAndExecute(rule, task, taskId, eventKey);
  }
}

async function processKnowledgeReviewReminders(now) {
  const snapshot = await db.collection("documents")
      .where("status", "==", "approved")
      .get();
  const managers = await db.collection("users").where("role", "==", "manager").get();
  const managerUids = managers.docs
      .filter((doc) => doc.data().accountStatus === "active")
      .map((doc) => doc.id);
  let reminders = 0;
  for (const documentDoc of snapshot.docs) {
    const document = documentDoc.data();
    if (!document.reviewDueDate) continue;
    const due = new Date(document.reviewDueDate);
    if (Number.isNaN(due.getTime())) continue;
    const daysRemaining = (due.getTime() - now.getTime()) / 86400000;
    if (daysRemaining > 7) continue;
    if (document.reviewReminderForDate === document.reviewDueDate) continue;

    const recipients = new Set(managerUids);
    if (document.ownerUid) recipients.add(document.ownerUid);
    const batch = db.batch();
    for (const recipientUid of recipients) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        notificationId: ref.id,
        recipientUid,
        type: "knowledgeReviewDue",
        title: daysRemaining < 0 ? "تأخرت مراجعة وثيقة" : "اقترب موعد مراجعة وثيقة",
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
    reminders++;
  }
  return {checked: snapshot.size, reminders};
}

async function main() {
  const now = new Date();
  const [ruleSnapshot, taskSnapshot] = await Promise.all([
    db.collection("automation_rules").where("isActive", "==", true).get(),
    db.collection("tasks").get(),
  ]);
  const rules = ruleSnapshot.docs.map((doc) => doc.data());
  let executedTasks = 0;
  for (const taskDoc of taskSnapshot.docs) {
    const task = taskDoc.data();
    const stateRef = db.collection("automation_state").doc(taskDoc.id);
    const stateSnapshot = await stateRef.get();
    const state = stateSnapshot.data();
    const createdAt = new Date(task.createdAt || 0);
    if (!stateSnapshot.exists && !Number.isNaN(createdAt.getTime()) &&
        now.getTime() - createdAt.getTime() <= 45 * 60 * 1000) {
      await processRules(rules, task, taskDoc.id, "taskCreated", `created_${task.createdAt}`, now);
    }
    if (stateSnapshot.exists && state.lastStatus !== task.status) {
      await processRules(rules, task, taskDoc.id, "statusChanged", `status_${task.status}_${task.updatedAt}`, now);
    }
    await processRules(rules, task, taskDoc.id, "dueSoon", `dueSoon_${task.dueDate}`, now);
    await processRules(rules, task, taskDoc.id, "overdue", `overdue_${task.dueDate}`, now);
    await stateRef.set({
      taskId: taskDoc.id,
      lastStatus: task.status || "",
      lastUpdatedAt: task.updatedAt || "",
      checkedAt: now.toISOString(),
    });
    executedTasks++;
  }
  const knowledge = await processKnowledgeReviewReminders(now);
  console.log(`Automation scan complete: ${rules.length} active rules, ${executedTasks} tasks checked, ${knowledge.checked} approved knowledge documents checked, ${knowledge.reminders} review reminders sent`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
