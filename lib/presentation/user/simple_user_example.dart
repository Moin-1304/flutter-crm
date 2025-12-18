import 'package:flutter/material.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/core/data/network/dio/configs/dio_configs.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';

/// Simple example showing how to use the UserDetailStore with ChangeNotifier
class SimpleUserExample extends StatefulWidget {
  const SimpleUserExample({Key? key}) : super(key: key);

  @override
  State<SimpleUserExample> createState() => _SimpleUserExampleState();
}

class _SimpleUserExampleState extends State<SimpleUserExample> {
  late UserDetailStore _userStore;
  final TextEditingController _userIdController = TextEditingController(text: '40');
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeStore();
  }

  void _initializeStore() {
    // Initialize Dio client with DioConfigs
    final dioConfigs = DioConfigs(
      baseUrl: Endpoints.baseUrl,
      connectionTimeout: Endpoints.connectionTimeout,
      receiveTimeout: Endpoints.receiveTimeout,
    );
    
    final dioClient = DioClient(dioConfigs: dioConfigs);
    final userApiClient = UserApiClient(dioClient);
    final errorStore = ErrorStore();
    
    _userStore = UserDetailStore(userApiClient, errorStore);
    
    // Listen to store changes
    _userStore.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    setState(() {
      // This will trigger a rebuild when the store changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple User API Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input fields
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
                hintText: 'Enter user ID (e.g., 40)',
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Bearer Token',
                border: OutlineInputBorder(),
                hintText: 'Enter your bearer token',
              ),
              obscureText: true,
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _fetchUserData,
              child: const Text('Fetch User Data'),
            ),
            
            const SizedBox(height: 24),
            
            // Display results
            Expanded(
              child: _buildUserDisplay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDisplay() {
    if (_userStore.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading user data...'),
          ],
        ),
      );
    }
    
    if (_userStore.errorMessage != null) {
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Error occurred:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _userStore.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_userStore.isUserLoaded) {
      return _buildUserInfo();
    }
    
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Enter user ID and token, then click "Fetch User Data"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _userStore.userDetail!;
    
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userStore.userDisplayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.company,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Basic Info
              _buildInfoSection('Basic Information', [
                _buildInfoRow('User ID', user.id.toString()),
                _buildInfoRow('Employee ID', user.employeeId.toString()),
                _buildInfoRow('Phone', user.phoneNumber),
                _buildInfoRow('Status', user.activeText),
                _buildInfoRow('Service Area', user.serviceArea),
              ]),
              
              // Divisions
              if (user.divisions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInfoSection('Divisions', [
                  ...user.divisions.map((division) => 
                    _buildInfoRow('Division ${division.division}', division.divisionText),
                  ),
                ]),
              ],
              
              // Roles
              if (user.roles.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInfoSection('Roles', [
                  ...user.roles.map((role) => 
                    _buildInfoRow('Role ID ${role.roleId}', 'Active'),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'N/A' : value),
          ),
        ],
      ),
    );
  }

  void _fetchUserData() {
    final userId = int.tryParse(_userIdController.text);
    final token = _tokenController.text.trim();
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid user ID')),
      );
      return;
    }
    
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bearer token')),
      );
      return;
    }
    
    _userStore.setAuthToken(token);
    _userStore.fetchUserById(userId);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _tokenController.dispose();
    _userStore.removeListener(_onStoreChanged);
    _userStore.dispose();
    super.dispose();
  }
}
