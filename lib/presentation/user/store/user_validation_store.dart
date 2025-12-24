import 'package:flutter/material.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/di/service_locator.dart';

class UserValidationStore extends ChangeNotifier {
  bool? _isUserValid;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool? get isUserValid => _isUserValid;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Computed getters for button states
  bool get canCreateTourPlan => _isUserValid == true;
  bool get canUpdateTourPlan => _isUserValid == true;
  bool get canCreateDcr => _isUserValid == true;
  bool get canUpdateDcr => _isUserValid == true;
  bool get canCreateDeviation => _isUserValid == true;

  /// Validate user by calling the API
  Future<void> validateUser(int userId) async {
    if (_isLoading) {
      print(
          '⏳ [UserValidationStore] validateUser already in progress, skipping...');
      return; // Prevent multiple simultaneous calls
    }

    print('🚀 [UserValidationStore] Starting validateUser for userId: $userId');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (getIt.isRegistered<DcrRepository>()) {
        final dcrRepository = getIt<DcrRepository>();
        print(
            '📞 [UserValidationStore] Calling DcrRepository.validateUser($userId)');
        final response = await dcrRepository.validateUser(userId);
        _isUserValid = response.isValid;
        print(
            '✅ [UserValidationStore] Validation result: isValid = ${response.isValid}');
        print(
            '   Button states: canCreateTourPlan=$canCreateTourPlan, canCreateDcr=$canCreateDcr, canCreateDeviation=$canCreateDeviation');
      } else {
        _isUserValid = false;
        _errorMessage = 'DCR Repository not available';
        print('❌ [UserValidationStore] DCR Repository not registered');
      }
    } catch (e) {
      _isUserValid = false;
      _errorMessage = 'Failed to validate user: ${e.toString()}';
      print('❌ [UserValidationStore] Error validating user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🏁 [UserValidationStore] validateUser completed');
    }
  }

  /// Reset validation state
  void reset() {
    _isUserValid = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
