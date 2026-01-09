import '../../../domain/repository/attendance/punch_in_out_repository.dart';
import '../../../domain/entity/attendance/punch_in_out_api_models.dart';
import '../../network/apis/attendance/punch_in_out_api.dart';

class PunchInOutRepositoryImpl implements PunchInOutRepository {
  final PunchInOutApi _punchInOutApi;

  PunchInOutRepositoryImpl(this._punchInOutApi);

  @override
  Future<PunchInOutResponse> savePunchInOut(PunchInOutSaveRequest request) async {
    try {
      return await _punchInOutApi.savePunchInOut(request);
    } catch (e) {
      // Preserve the user-friendly error message from API layer
      final errorString = e.toString();
      if (e is Exception && (errorString.contains('Server error') || 
          errorString.contains('Connection error') ||
          errorString.contains('Network error') ||
          errorString.contains('Authentication failed'))) {
        // Re-throw as-is if it's already a user-friendly message
        rethrow;
      }
      throw Exception('Failed to save punch in/out. Please try again.');
    }
  }

  @override
  Future<PunchInOutListResponse> getPunchInOutList(PunchInOutListRequest request) async {
    try {
      return await _punchInOutApi.getPunchInOutList(request);
    } catch (e) {
      // Preserve the user-friendly error message from API layer
      if (e is Exception && (e.toString().contains('Server error') || 
          e.toString().contains('Connection error') ||
          e.toString().contains('Network error') ||
          e.toString().contains('Authentication failed'))) {
        // Re-throw as-is if it's already a user-friendly message
        rethrow;
      }
      throw Exception('Failed to load punch records. Please try again.');
    }
  }
}
