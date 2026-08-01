import 'package:flutter/material.dart';
import '../manager/manager_employees_tab.dart';

/// Exact read-only mirror of the manager's employees workspace. Manager
/// controls remain visible so the observer can understand the real workflow,
/// but every write action is disabled by [ManagerEmployeesTab.readOnly].
class DesignerEmployeesTab extends StatelessWidget {
  const DesignerEmployeesTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const ManagerEmployeesTab(readOnly: true);
}
