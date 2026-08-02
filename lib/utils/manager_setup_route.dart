/// Decides whether the signed-out root route should open the one-time
/// manager inauguration flow.
///
/// `/login` always remains available for existing operational accounts such
/// as employee 400161, while the root route stays reserved for the first
/// official manager until Firestore creates `system/manager_lock`.
bool shouldShowManagerSetup({
  required bool forceLogin,
  required bool managerStatusReady,
  required bool managerExists,
}) {
  return !forceLogin && managerStatusReady && !managerExists;
}
