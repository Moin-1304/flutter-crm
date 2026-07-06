import '../../entity/attendance/punch_in_out_api_models.dart';
import '../../repository/attendance/punch_in_out_repository.dart';
import '../../../core/domain/usecase/use_case_result.dart';
import 'package:intl/intl.dart';

class PunchInOutUseCase {
  final PunchInOutRepository _punchInOutRepository;

  PunchInOutUseCase(this._punchInOutRepository);

  /// Save punch in/out record.
  /// CheckInStatus: 0 = Check In (KilometerIn), 1 = Check Out (KilometerOut).
  Future<UseCaseResult<PunchInOutResponse>> savePunchInOut({
    required int userId,
    required int employeeId,
    required int sbuId,
    required int createdBy,
    required int status,
    required int bizUnit,
    required bool isPunchIn, // true for punch in, false for punch out
    String userName = '',
    String sbuName = '',
    String? lastLoggedOutTime,
    List<LogDetail> logDetails = const [],
    double? kilometerIn,  // Vehicle mileage at punch in (required when isPunchIn is true)
    double? kilometerOut, // Vehicle mileage at punch out (required when isPunchIn is false)
    double? privateKilometers, // Personal travel distance entered during work time
  }) async {
    try {
      final request = PunchInOutSaveRequest(
        id: 0,
        createdBy: createdBy,
        status: status,
        sbuId: sbuId,
        employeeId: employeeId,
        userId: userId,
        checkInStatus: isPunchIn ? 1 : 0,
        bizUnit: bizUnit,
        kilometerIn: isPunchIn ? kilometerIn : null,
        kilometerOut: isPunchIn ? null : kilometerOut,
        privateKilometers: isPunchIn ? 0 : (privateKilometers ?? 0),
        userName: userName,
        sbuName: sbuName,
        lastLoggedOutTime: lastLoggedOutTime,
        logDetails: logDetails,
        isCheckout: isPunchIn ? 0 : 1,
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
      // API expects date-only value for reliable day-wise filtering.
      final dateStr = logDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      
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
