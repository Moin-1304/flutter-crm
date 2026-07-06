import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/domain/entity/user/user_detail.dart';

/// Prevents managers from reviewing or approving CRM records they own.
class ManagerReviewHelper {
  ManagerReviewHelper._();

  static int? loggedInEmployeeId(UserDetail? user) {
    final int id = user?.employeeId ?? 0;
    if (id <= 0) return null;
    return id;
  }

  static String employeeFilterLabel(CommonDropdownItem item) {
    final String name =
        (item.employeeName.isNotEmpty ? item.employeeName : item.text).trim();
    final String text = item.text.trim();
    final String code = item.code.trim();

    if (text.contains(' - ') && text.length >= name.length) {
      return text;
    }
    if (code.isNotEmpty && name.isNotEmpty) {
      return '$code - $name';
    }
    return name.isNotEmpty ? name : text;
  }

  /// True when this dropdown row is the logged-in manager (skip for team filters).
  static bool isLoggedInManagerItem(
    CommonDropdownItem item,
    UserDetail? user,
  ) {
    final int? managerId = loggedInEmployeeId(user);
    if (managerId == null) return false;

    if (item.id == managerId) return true;
    if (item.value > 0 && item.value == managerId) return true;

    return _labelMatchesLoggedInManager(employeeFilterLabel(item), user);
  }

  static bool _labelMatchesLoggedInManager(String label, UserDetail? user) {
    if (user == null) return false;
    final String normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final List<String> managerNames = _loggedInManagerNameVariants(user);
    for (final String name in managerNames) {
      if (normalized == name) return true;
      if (normalized.endsWith(' - $name')) return true;
      final List<String> parts = normalized.split(' - ');
      if (parts.length >= 2 && parts.last.trim() == name) return true;
    }
    return false;
  }

  static List<String> _loggedInManagerNameVariants(UserDetail user) {
    final Set<String> names = <String>{};
    void add(String? value) {
      final String v = (value ?? '').trim().toLowerCase();
      if (v.isNotEmpty) names.add(v);
    }

    add(user.employeeName);
    add(user.name);
    add(user.userName);
    add('${user.firstName} ${user.lastName}');
    add(user.firstName);
    return names.toList();
  }

  static List<CommonDropdownItem> teamItemsExcludingLoggedInManager(
    List<CommonDropdownItem> items,
    UserDetail? user,
  ) {
    return items
        .where((item) => !isLoggedInManagerItem(item, user))
        .toList();
  }

  static void removeLoggedInManagerFromNameMap(
    Map<String, int> nameToId,
    UserDetail? user,
  ) {
    final int? managerId = loggedInEmployeeId(user);
    nameToId.removeWhere((label, id) {
      if (managerId != null && id == managerId) return true;
      return _labelMatchesLoggedInManager(label, user);
    });
  }

  static List<String> buildTeamFilterOptions(
    List<CommonDropdownItem> items,
    UserDetail? user, {
    required String allStaffOption,
  }) {
    final List<CommonDropdownItem> team =
        teamItemsExcludingLoggedInManager(items, user);
    final Set<String> names = team
        .map(employeeFilterLabel)
        .where((s) => s.isNotEmpty)
        .toSet();
    return [allStaffOption, ...names];
  }

  /// Final safety net for filter UI — never show logged-in manager in dropdown.
  static List<String> filterOptionsForDisplay(
    List<String> options,
    Map<String, int> nameToId,
    UserDetail? user, {
    required String allStaffOption,
  }) {
    final int? managerId = loggedInEmployeeId(user);
    return options.where((option) {
      if (option == allStaffOption) return true;
      if (managerId != null && nameToId[option] == managerId) return false;
      if (_labelMatchesLoggedInManager(option, user)) return false;
      return true;
    }).toList();
  }

  static String? normalizeTeamEmployeeSelection({
    required String? selected,
    required List<String> options,
    required Map<String, int> nameToId,
    required UserDetail? loggedInUser,
    required String allStaffOption,
  }) {
    final List<String> safeOptions = filterOptionsForDisplay(
      options,
      nameToId,
      loggedInUser,
      allStaffOption: allStaffOption,
    );

    if (selected == null || !safeOptions.contains(selected)) {
      return safeOptions.contains(allStaffOption) ? allStaffOption : null;
    }
    return selected;
  }

  /// Returns true when the logged-in manager is the owner/creator of the record.
  static bool isOwnEmployeeRecord({
    required UserDetail? loggedInUser,
    required int recordEmployeeId,
    int? recordCreatedBy,
    int? recordUserId,
  }) {
    final int? loginEmployeeId = loggedInEmployeeId(loggedInUser);
    if (loginEmployeeId == null) return false;

    if (recordEmployeeId > 0 && loginEmployeeId == recordEmployeeId) {
      return true;
    }
    if (recordCreatedBy != null &&
        recordCreatedBy > 0 &&
        loginEmployeeId == recordCreatedBy) {
      return true;
    }

    final int? loginUserId = loggedInUser?.userId ?? loggedInUser?.id;
    if (loginUserId != null &&
        loginUserId > 0 &&
        recordUserId != null &&
        recordUserId > 0 &&
        loginUserId == recordUserId) {
      return true;
    }
    return false;
  }
}
