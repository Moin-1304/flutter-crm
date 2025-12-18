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
      throw Exception('Failed to save punch in/out: ${e.toString()}');
    }
  }

  @override
  Future<PunchInOutListResponse> getPunchInOutList(PunchInOutListRequest request) async {
    try {
      return await _punchInOutApi.getPunchInOutList(request);
    } catch (e) {
      throw Exception('Failed to get punch in/out list: ${e.toString()}');
    }
  }
}
