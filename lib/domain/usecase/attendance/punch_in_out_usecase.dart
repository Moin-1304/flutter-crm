import '../../entity/attendance/punch_in_out_api_models.dart';
import '../../repository/attendance/punch_in_out_repository.dart';
import '../../../core/domain/usecase/use_case_result.dart';

class PunchInOutUseCase {
  final PunchInOutRepository _punchInOutRepository;

  PunchInOutUseCase(this._punchInOutRepository);

  /// Save punch in/out record
  Future<UseCaseResult<PunchInOutResponse>> savePunchInOut({
    required int userId,
    required int employeeId,
    required int sbuId,
    required int createdBy,
    required int status,
    required int bizUnit,
    required bool isPunchIn, // true for punch in, false for punch out
  }) async {
    try {
      final request = PunchInOutSaveRequest(
        id: 0,
        createdBy: createdBy,
        status: status,
        sbuId: sbuId,
        employeeId: employeeId,
        userId: userId,
        checkInStatus: isPunchIn ? 1 : 0, // 1 for punch in, 0 for punch out
        bizUnit: bizUnit,
      );

      final response = await _punchInOutRepository.savePunchInOut(request);
      return UseCaseResult.success(response);
    } catch (e) {
      return UseCaseResult.error(e.toString());
    }
  }

  /// Get punch in/out list for today
  Future<UseCaseResult<PunchInOutListResponse>> getTodayPunchInOutList({
    required int userId,
    String? logDate, // If null, uses today's date
  }) async {
    try {
      final today = DateTime.now().toUtc();
      final dateStr = logDate ?? today.toIso8601String();
      
      final request = PunchInOutListRequest(
        pageNumber: 0,
        pageSize: 100, // Get more records for today
        sortOrder: 0,
        sortDir: 0,
        searchText: '',
        userId: userId,
        logDate: dateStr,
      );

      final response = await _punchInOutRepository.getPunchInOutList(request);
      return UseCaseResult.success(response);
    } catch (e) {
      return UseCaseResult.error(e.toString());
    }
  }

  /// Get punch in/out list with custom parameters
  Future<UseCaseResult<PunchInOutListResponse>> getPunchInOutList({
    required int userId,
    required int pageNumber,
    required int pageSize,
    required String logDate,
    String searchText = '',
    int sortOrder = 0,
    int sortDir = 0,
  }) async {
    try {
      final request = PunchInOutListRequest(
        pageNumber: pageNumber,
        pageSize: pageSize,
        sortOrder: sortOrder,
        sortDir: sortDir,
        searchText: searchText,
        userId: userId,
        logDate: logDate,
      );

      final response = await _punchInOutRepository.getPunchInOutList(request);
      return UseCaseResult.success(response);
    } catch (e) {
      return UseCaseResult.error(e.toString());
    }
  }
}
