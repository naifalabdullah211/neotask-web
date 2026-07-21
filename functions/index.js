/**
 * NeoTask Cloud Functions (neotask1-ff5a4)
 *
 * ------------------------------------------------------------------------
 * DEPLOYMENT STATUS (as of this writing): WRITTEN, NOT DEPLOYED.
 *
 * A real test deployment of a disposable dummy function to this exact
 * project confirmed the following blocker:
 *   "Cloud Functions deployment requires the Cloud Build API to be
 *    enabled. The current credentials do not have permission to enable
 *    APIs for project neotask1-ff5a4."
 * Attempts to enable the Service Usage API, read the Cloud Billing plan,
 * and read IAM policy directly all returned 403 (the sandbox's Firebase
 * Admin SDK service-account key is deliberately scoped to Firestore/Auth
 * Admin only — it cannot perform Owner-level project actions).
 *
 * Deploying this file requires the PROJECT OWNER to, via the Firebase/GCP
 * Console (NOT possible from this sandbox):
 *   1. Upgrade the project's billing plan to Blaze (pay-as-you-go).
 *   2. Enable the Cloud Build API, Artifact Registry API, and Cloud
 *      Functions API for neotask1-ff5a4.
 * Then run, from a machine/session with Owner-level `gcloud`/`firebase`
 * CLI auth:
 *   cd functions && npm install
 *   firebase deploy --only functions --project neotask1-ff5a4
 * ------------------------------------------------------------------------
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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

  const {userId, newPassword} = data || {};

  // 2) Basic input validation.
  if (typeof userId !== "string" || userId.trim().length === 0) {
    throw new HttpsError(
        "invalid-argument",
        "معرّف المستخدم المستهدف غير صالح",
    );
  }
  if (typeof newPassword !== "string" || newPassword.length < 6) {
    throw new HttpsError(
        "invalid-argument",
        "كلمة المرور الجديدة يجب أن تتكون من 6 أحرف على الأقل",
    );
  }

  // 3) Server-side manager-role verification via Firestore lookup.
  const db = admin.firestore();
  const callerSnap = await db.collection("users").doc(auth.uid).get();
  if (!callerSnap.exists) {
    throw new HttpsError(
        "permission-denied",
        "لا يمكن التحقق من صلاحياتك",
    );
  }
  const callerData = callerSnap.data();
  const isManager = callerData && callerData.role === "manager";
  const isActive = callerData && callerData.accountStatus === "active";
  if (!isManager || !isActive) {
    throw new HttpsError(
        "permission-denied",
        "ليس لديك صلاحية تغيير كلمات مرور الموظفين",
    );
  }

  // 4) Target user must exist.
  const targetSnap = await db.collection("users").doc(userId).get();
  if (!targetSnap.exists) {
    throw new HttpsError(
        "not-found",
        "المستخدم المستهدف غير موجود",
    );
  }

  // 5) Perform the privileged password update via the Admin SDK.
  try {
    await admin.auth().updateUser(userId, {password: newPassword});
  } catch (err) {
    if (err && err.code === "auth/user-not-found") {
      throw new HttpsError(
          "not-found",
          "حساب المصادقة لهذا المستخدم غير موجود",
      );
    }
    throw new HttpsError(
        "internal",
        "تعذّر تغيير كلمة المرور: " + (err && err.message ? err.message : "خطأ غير معروف"),
    );
  }

  return {success: true};
});
