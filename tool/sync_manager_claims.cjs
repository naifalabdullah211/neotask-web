const admin = require('firebase-admin');

const PROJECT_ID = 'neotask1-ff5a4';

function normalizedEmployeeNumber(value) {
  return String(value || '').replace(/\D/g, '');
}

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();
  const auth = admin.auth();
  const snapshot = await db.collection('users').get();

  let enabled = 0;
  let disabled = 0;
  let unchanged = 0;
  let missingAuthUsers = 0;

  for (const document of snapshot.docs) {
    const data = document.data() || {};
    const uid = String(data.uid || document.id || '').trim();
    if (!uid) continue;

    const shouldBeManager =
      data.accountStatus === 'active' &&
      (data.role === 'manager' ||
        normalizedEmployeeNumber(data.employeeNumber) === '400161');

    let authUser;
    try {
      authUser = await auth.getUser(uid);
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        missingAuthUsers += 1;
        continue;
      }
      throw error;
    }

    const claims = {...(authUser.customClaims || {})};
    const currentlyManager = claims.neoTaskManager === true;

    if (shouldBeManager && !currentlyManager) {
      claims.neoTaskManager = true;
      await auth.setCustomUserClaims(uid, claims);
      enabled += 1;
      continue;
    }

    if (!shouldBeManager && currentlyManager) {
      delete claims.neoTaskManager;
      await auth.setCustomUserClaims(uid, claims);
      disabled += 1;
      continue;
    }

    unchanged += 1;
  }

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    scanned: snapshot.size,
    enabled,
    disabled,
    unchanged,
    missingAuthUsers,
  }));
}

main().catch((error) => {
  console.error('manager-claim-sync-failed', error?.code || error?.name || 'unknown');
  process.exitCode = 1;
});
