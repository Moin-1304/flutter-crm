import '../../entity/attendance/punch_in_out_api_models.dart';

abstract class PunchInOutRepository {
  /// Save punch in/out record
  Future<PunchInOutResponse> savePunchInOut(PunchInOutSaveRequest request);

  /// Get punch in/out list
  Future<PunchInOutListResponse> getPunchInOutList(PunchInOutListRequest request);
}
