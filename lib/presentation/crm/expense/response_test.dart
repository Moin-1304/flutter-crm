import 'package:flutter/material.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';

/// Test widget to verify the API response parsing fix
class ResponseTestWidget extends StatelessWidget {
  const ResponseTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Response Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Testing API Response Parsing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => _testResponseParsing(),
              child: const Text('Test Response Parsing'),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Expected Results:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text('✅ Success should be true (from isSuccess field)'),
            const Text('✅ Message should be empty (from message field)'),
            const Text('✅ No more "Failed to send back expense" errors'),
          ],
        ),
      ),
    );
  }

  void _testResponseParsing() {
    // Simulate the actual API response
    final Map<String, dynamic> apiResponse = {
      "data": {},
      "isSuccess": true,
      "message": "",
      "exception": null,
      "retVal": 0,
      "errorNumber": 0,
      "outputType": 0,
      "errorMessage": "",
      "dataReader": null,
      "outputParameters": null
    };

    // Test the parsing
    final response = ExpenseActionResponse.fromJson(apiResponse);
    
    print('=== API Response Parsing Test ===');
    print('Raw API Response: $apiResponse');
    print('Parsed Success: ${response.success}');
    print('Parsed Message: "${response.message}"');
    print('Expected Success: true');
    print('Expected Message: ""');
    print('Test Result: ${response.success == true ? "✅ PASS" : "❌ FAIL"}');
    print('================================');
  }
}





