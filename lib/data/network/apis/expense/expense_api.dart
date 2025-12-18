import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import 'expense_api_models.dart';

class ExpenseApi {
  final DioClient _dioClient;

  ExpenseApi(this._dioClient);

  /// Upload file using File Upload API (Option 1 - Recommended)
  /// POST /erpweb/api/FilesUpload/upload?relativePath=Uploads/Attachments/DCR/Expenses
  /// Request: form-data with key 'file'
  /// Response: { success: true, fileName: "...", path: "..." }
  Future<FileUploadResponse> uploadFile(
    PlatformFile file, {
    String relativePath = 'Uploads/Attachments/DCR/Expenses',
  }) async {
    try {
      print('Uploading file: ${file.name}');
      
      // Prepare file for upload
      MultipartFile multipartFile;
      if (file.bytes != null) {
        // Use bytes if available
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        );
      } else if (file.path != null) {
        // Use file path if bytes not available
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        );
      } else {
        throw Exception('File has neither bytes nor path');
      }

      // Create FormData
      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      // Upload file
      final response = await _dioClient.dio.post(
        Endpoints.fileUpload(relativePath: relativePath),
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('File upload response: ${response.data}');
      
      if (response.data != null) {
        return FileUploadResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received from file upload');
      }
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  /// Get Base URL for file uploads (Option 2 - Fallback)
  /// GET /erpweb/api/FilesUpload/GetBaseUrl
  /// Response: { success: true, baseUrl: "..." }
  Future<FileUploadBaseUrlResponse> getFileUploadBaseUrl() async {
    try {
      final response = await _dioClient.dio.get(
        Endpoints.fileUploadGetBaseUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return FileUploadBaseUrlResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received from GetBaseUrl');
      }
    } catch (e) {
      throw Exception('Failed to get file upload base URL: ${e.toString()}');
    }
  }

  /// Save Expense
  /// URL: /api/PharmaCRM/DCR/SaveExpenses
  /// Backend expects JSON with Attachments containing: FileName, FileType, FilePath, Type (NO FileData)
  /// FilePath and fileName are obtained from the file upload API response
  Future<Map<String, dynamic>> saveExpense(
    ExpenseSaveRequest request, {
    List<PlatformFile>? files,
  }) async {
    try {
      // If files are provided, upload them first using Option 1 (File Upload API)
      if (files != null && files.isNotEmpty) {
        final attachmentsWithFilePath = <ExpenseAttachment>[];
        
        for (final file in files) {
          print('Processing file: ${file.name}');
          
          try {
            // Upload file using Option 1 (File Upload API)
            final uploadResponse = await uploadFile(
              file,
              relativePath: 'Uploads/Attachments/DCR/Expenses',
            );
            
            print('File uploaded successfully:');
            print('  - Original fileName: ${file.name}');
            print('  - Uploaded fileName: ${uploadResponse.fileName}');
            print('  - Uploaded path: ${uploadResponse.path}');
            
            // Determine file type from extension
            final extension = file.extension?.toLowerCase() ?? '';
            String fileType = 'FILE';
            if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
              fileType = 'IMG';
            } else if (extension == 'pdf') {
              fileType = 'PDF';
            } else if (['doc', 'docx'].contains(extension)) {
              fileType = 'DOC';
            } else if (['xls', 'xlsx'].contains(extension)) {
              fileType = 'XLS';
            } else if (['ppt', 'pptx'].contains(extension)) {
              fileType = 'PPT';
            } else if (extension == 'txt') {
              fileType = 'TXT';
            }
            
            // Use the fileName and path returned from the upload API
            attachmentsWithFilePath.add(
              ExpenseAttachment(
                fileName: uploadResponse.fileName, // Use fileName from upload response
                fileType: fileType, // IMG, PDF, DOC, etc.
                filePath: uploadResponse.path, // Use path from upload response
                type: extension.isNotEmpty ? extension : 'file', // File extension
                fileData: null, // No FileData - not included in request
              ),
            );
            
            print('Attachment prepared with uploaded fileName and path');
          } catch (uploadError) {
            print('Error uploading file ${file.name}: $uploadError');
            // If Option 1 fails, log error but continue with other files
            // Optionally, could implement fallback to Option 2 here
            print('Skipping file ${file.name} due to upload error');
          }
        }
        
        // Create request with attachments containing fileName and path from upload API
        final requestWithFiles = ExpenseSaveRequest(
          id: request.id,
          dcrId: request.dcrId,
          dateOfExpense: request.dateOfExpense,
          employeeId: request.employeeId,
          cityId: request.cityId,
          clusterId: request.clusterId,
          bizUnit: request.bizUnit,
          expenceType: request.expenceType,
          expenseAmount: request.expenseAmount,
          remarks: request.remarks,
          userId: request.userId,
          dcrStatus: request.dcrStatus,
          dcrStatusId: request.dcrStatusId,
          clusterNames: request.clusterNames,
          isGeneric: request.isGeneric,
          employeeName: request.employeeName,
          attachments: attachmentsWithFilePath,
        );
        
        final requestJson = requestWithFiles.toJson();
        
        // Verify the JSON structure
        print('=== FINAL REQUEST STRUCTURE ===');
        print('Request JSON keys: ${requestJson.keys.toList()}');
        print('Attachments count: ${requestJson['Attachments']?.length ?? 0}');
        
        if (requestJson['Attachments'] != null && (requestJson['Attachments'] as List).isNotEmpty) {
          final firstAttachment = (requestJson['Attachments'] as List).first as Map<String, dynamic>;
          print('First attachment keys: ${firstAttachment.keys.toList()}');
          print('FileName: ${firstAttachment['FileName']}');
          print('FileType: ${firstAttachment['FileType']}');
          print('FilePath: "${firstAttachment['FilePath']}"');
          print('Type: ${firstAttachment['Type']}');
          print('FileData present: ${firstAttachment.containsKey('FileData')} (should be false)');
          print('=== END REQUEST STRUCTURE ===');
        }
        
        final response = await _dioClient.dio.post(
          Endpoints.expenseSave,
          data: requestJson,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        final responseData = response.data ?? {};
        print('SaveExpense Response - Expense ID: ${responseData['id']}');
        print('SaveExpense Response - Attachments: ${responseData['attachments'] ?? responseData['Attachments']}');
        
        return responseData;
      } else {
        // No files, send as JSON
        final response = await _dioClient.dio.post(
          Endpoints.expenseSave,
          data: request.toJson(),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        return response.data ?? {};
      }
    } catch (e) {
      throw Exception('Failed to save expense: ${e.toString()}');
    }
  }

  /// Get Expense Details
  /// URL: /api/PharmaCRM/DCR/GetExpense?Id={id}
  Future<ExpenseDetailResponse> getExpense(int expenseId) async {
    try {
      final response = await _dioClient.dio.get(
        '${Endpoints.expenseGet}?Id=$expenseId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        // Log the raw response for debugging
        print('GetExpense API Response: ${response.data}');
        print('Attachments in response: ${response.data['attachments']}');
        
        return ExpenseDetailResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get expense details: ${e.toString()}');
    }
  }

  /// Approve Single Expense
  /// URL: /api/PharmaCRM/DCR/ApproveExpenseSingle
  Future<ExpenseActionResponse> approveExpenseSingle(ExpenseActionRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.expenseApproveSingle,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return ExpenseActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to approve expense: ${e.toString()}');
    }
  }

  /// Send Back Single Expense
  /// URL: /api/PharmaCRM/DCR/SendBackExpenseSingle
  Future<ExpenseActionResponse> sendBackExpenseSingle(ExpenseActionRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.expenseSendBackSingle,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return ExpenseActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to send back expense: ${e.toString()}');
    }
  }

  /// Bulk Approve Expenses
  /// URL: /api/PharmaCRM/DCR/BulkApproveExpense
  Future<ExpenseActionResponse> bulkApproveExpenses(ExpenseBulkApproveRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.expenseBulkApprove,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return ExpenseActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to bulk approve expenses: ${e.toString()}');
    }
  }

  /// Bulk Reject Expenses
  /// URL: /api/PharmaCRM/DCR/BulkRejectExpense
  Future<ExpenseActionResponse> bulkRejectExpenses(ExpenseBulkRejectRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.expenseBulkReject,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return ExpenseActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to bulk reject expenses: ${e.toString()}');
    }
  }
}
