import 'package:flutter/material.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/di/service_locator.dart';

/// Demo screen to test the API integration
class ApiTestDemo extends StatefulWidget {
  const ApiTestDemo({super.key});

  @override
  State<ApiTestDemo> createState() => _ApiTestDemoState();
}

class _ApiTestDemoState extends State<ApiTestDemo> {
  late final TourPlanStore _store;
  String _testResults = '';

  @override
  void initState() {
    super.initState();
    _store = getIt<TourPlanStore>();
  }

  Future<void> _testApiCall() async {
    setState(() {
      _testResults = 'Testing API call...\n';
    });

    try {
      // Test with current month
      final now = DateTime.now();
      
      print('🧪 API Test Demo: Starting API test for ${now.month}/${now.year}');
      
      await _store.loadCalendarViewData(
        month: now.month,
        year: now.year,
        userId: 123,
        managerId: 456,
        employeeId: 789,
      );

      final results = _store.calendarViewData;
      
      setState(() {
        _testResults += '✅ API call successful!\n';
        _testResults += '📊 Received ${results.length} calendar entries\n\n';
        
        // Show first few entries
        for (int i = 0; i < results.length && i < 5; i++) {
          final data = results[i];
          _testResults += 'Day ${data.planDate.day}: ';
          _testResults += 'Planned=${data.plannedCount}, ';
          _testResults += 'Weekend=${data.isWeekend}, ';
          _testResults += 'Holiday=${data.isHolidayDay}\n';
        }
        
        if (results.length > 5) {
          _testResults += '... and ${results.length - 5} more entries\n';
        }
      });

      print('🧪 API Test Demo: Test completed successfully');
      
    } catch (e) {
      setState(() {
        _testResults += '❌ API call failed: $e\n';
      });
      print('🧪 API Test Demo: Test failed with error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tour Plan Calendar View API Test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _testApiCall,
              child: const Text('Test API Call'),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'Click "Test API Call" to start testing' : _testResults,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Check the console/logs for detailed API call information',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
