import 'package:flutter/material.dart';
import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/domain/entity/user/user_detail.dart';

class UserDetailStore extends ChangeNotifier {
  // repository instance
  final UserApiClient _userApiClient;

  // store for handling errors
  final ErrorStore errorStore;

  // constructor:---------------------------------------------------------------
  UserDetailStore(this._userApiClient, this.errorStore);

  // store variables:-----------------------------------------------------------
  bool _isLoading = false;
  UserDetail? _userDetail;
  String? _errorMessage;
  String? _authToken;

  // getters:-------------------------------------------------------------------
  bool get isLoading => _isLoading;
  UserDetail? get userDetail => _userDetail;
  String? get errorMessage => _errorMessage;
  String? get authToken => _authToken;
  bool get isUserLoaded => _userDetail != null;

  String get userDisplayName {
    if (_userDetail == null) return '';
    return '${_userDetail!.firstName}${_userDetail!.lastName}'.trim();
  }

  String get userEmail {
    return _userDetail?.email ?? '';
  }

  String get userCompany {
    return _userDetail?.company ?? '';
  }

  String get userServiceArea {
    return _userDetail?.serviceArea ?? '';
  }

  List<Division> get userDivisions {
    return _userDetail?.divisions ?? [];
  }

  List<UserRole> get userRoles {
    return _userDetail?.roles ?? [];
  }

  // actions:-------------------------------------------------------------------
  void setAuthToken(String token) {
    _authToken = token;
    notifyListeners();
  }

  void clearAuthToken() {
    _authToken = null;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setUserDetail(UserDetail? userDetail) {
    _userDetail = userDetail;
    notifyListeners();
  }

  void setErrorMessage(String? errorMessage) {
    _errorMessage = errorMessage;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearUserData() {
    _userDetail = null;
    _authToken = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch user details by ID
  Future<void> fetchUserById(int userId) async {
    if (_authToken == null) {
      setErrorMessage('Authentication token is required');
      return;
    }

    setLoading(true);
    clearError();

    try {
      final userDetail = await _userApiClient.getUserById(userId, _authToken!);
      setUserDetail(userDetail);
    } catch (e) {
      setErrorMessage('Failed to fetch user details: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  /// Refresh user data
  Future<void> refreshUserData() async {
    if (_userDetail != null) {
      await fetchUserById(_userDetail!.id);
    }
  }

  /// Check if user has specific role
  bool hasRole(int roleId) {
    if (_userDetail == null) return false;
    return _userDetail!.roles.any((role) => role.roleId == roleId);
  }

  /// Check if user has specific division
  bool hasDivision(int divisionId) {
    if (_userDetail == null) return false;
    return _userDetail!.divisions.any((division) => division.division == divisionId);
  }

  /// Get user's division names
  List<String> getDivisionNames() {
    if (_userDetail == null) return [];
    return _userDetail!.divisions.map((division) => division.divisionText).toList();
  }

  /// Get user's role IDs
  List<int> getRoleIds() {
    if (_userDetail == null) return [];
    return _userDetail!.roles.map((role) => role.roleId).toList();
  }

  // dispose:-------------------------------------------------------------------
  void dispose() {
    clearUserData();
  }
}
