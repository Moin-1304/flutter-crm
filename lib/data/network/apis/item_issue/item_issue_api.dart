import 'package:dio/dio.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/item_issue/item_issue_api_models.dart';

class ItemIssueApi {
  final DioClient _dioClient;

  ItemIssueApi(this._dioClient);

  /// Get ItemIssue list with filter criteria
  Future<ItemIssueListResponse> getItemIssueList(ItemIssueListRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.itemIssueList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return ItemIssueListResponse.fromJson(response.data);
      } else {
        throw Exception('No ItemIssue data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch ItemIssue list: ${e.toString()}');
    }
  }

  /// Get single ItemIssue by ID
  Future<ItemIssueApiItem> getItemIssue(int id) async {
    try {
      final url = Endpoints.itemIssueGet(id);
      print('═══════════════════════════════════════════════════════════');
      print('📥 ItemIssue Get API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: $url');
      print('Issue ID: $id');
      print('═══════════════════════════════════════════════════════════');
      
      final response = await _dioClient.dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'accept': 'text/plain',
          },
        ),
      );

      print('✅ ItemIssue Get API Response');
      print('   Status Code: ${response.statusCode}');
      print('   Has Data: ${response.data != null}');
      if (response.data != null) {
        print('   Response Keys: ${(response.data as Map).keys.toList()}');
        final apiItem = ItemIssueApiItem.fromJson(response.data);
        print('   Parsed Issue No: ${apiItem.no}');
        print('   Parsed Details Count: ${apiItem.details?.length ?? 0}');
        print('   Parsed Issue To: ${apiItem.issueTo}');
        print('   Parsed Issue Against: ${apiItem.issueAgainst}');
        return apiItem;
      } else {
        throw Exception('No ItemIssue data received');
      }
    } catch (e) {
      print('❌ ItemIssue Get API Error: $e');
      if (e is DioException && e.response != null) {
        print('   Status Code: ${e.response!.statusCode}');
        print('   Response Data: ${e.response!.data}');
      }
      throw Exception('Failed to get ItemIssue: ${e.toString()}');
    }
  }

  /// Save ItemIssue
  Future<ItemIssueSaveResponse> saveItemIssue(ItemIssueSaveRequest request) async {
    try {
      // Log request for debugging
      print('═══════════════════════════════════════════════════════════');
      print('📤 ItemIssue Save API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.itemIssueSave}');
      print('Request JSON:');
      print(request.toJson());
      print('═══════════════════════════════════════════════════════════');

      final response = await _dioClient.dio.post(
        Endpoints.itemIssueSave,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ ItemIssue Save API Success');
      print('Response Status: ${response.statusCode}');
      print('Response Data: ${response.data}');

      if (response.data != null) {
        return ItemIssueSaveResponse.fromJson(response.data);
      } else {
        throw Exception('No ItemIssue save response received');
      }
    } on DioException catch (e) {
      // Enhanced error handling for DioException
      String errorMessage = 'Failed to save ItemIssue';
      
      if (e.response != null) {
        // Server responded with error
        print('❌ ItemIssue Save API Error');
        print('Status Code: ${e.response?.statusCode}');
        print('Response Data: ${e.response?.data}');
        print('Response Headers: ${e.response?.headers}');
        
        // Try to extract error message from response headers first (errormessage field)
        final headers = e.response?.headers;
        if (headers != null && headers.map.containsKey('errormessage')) {
          final headerError = headers.map['errormessage']?.first;
          if (headerError != null && headerError.isNotEmpty) {
            errorMessage = headerError;
          }
        }
        
        // If no header error, try to extract from response body
        if (errorMessage == 'Failed to save ItemIssue') {
          final responseData = e.response?.data;
          if (responseData is Map) {
            final message = responseData['message'] ?? 
                           responseData['error'] ?? 
                           responseData['Message'] ?? 
                           responseData['Error'] ??
                           responseData['errormessage'];
            if (message != null) {
              errorMessage = message.toString();
            } else {
              errorMessage = 'Failed to save ItemIssue: ${responseData.toString()}';
            }
          } else if (responseData is String) {
            errorMessage = responseData;
          } else {
            errorMessage = 'Failed to save ItemIssue: Status ${e.response?.statusCode} - ${responseData?.toString() ?? "Unknown error"}';
          }
        }
      } else if (e.requestOptions != null) {
        // Request was sent but no response received
        errorMessage = 'Failed to save ItemIssue: No response from server';
      } else {
        // Request setup error
        errorMessage = 'Failed to save ItemIssue: ${e.message}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ ItemIssue Save API Exception: $e');
      throw Exception('Failed to save ItemIssue: ${e.toString()}');
    }
  }
}

