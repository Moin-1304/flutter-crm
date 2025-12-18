import 'package:flutter/material.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/core/data/network/dio/configs/dio_configs.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';

class UserProfileScreen extends StatefulWidget {
  final String authToken;
  final int userId;

  const UserProfileScreen({
    Key? key,
    required this.authToken,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late UserDetailStore _userStore;
  late ErrorStore _errorStore;

  @override
  void initState() {
    super.initState();
    _initializeStores();
    _loadUserData();
  }

  void _initializeStores() {
    _errorStore = ErrorStore();
    
    // Initialize Dio client with DioConfigs
    final dioConfigs = DioConfigs(
      baseUrl: Endpoints.baseUrl,
      connectionTimeout: Endpoints.connectionTimeout,
      receiveTimeout: Endpoints.receiveTimeout,
    );
    
    final dioClient = DioClient(dioConfigs: dioConfigs);
    final userApiClient = UserApiClient(dioClient);
    
    _userStore = UserDetailStore(userApiClient, _errorStore);
    _userStore.setAuthToken(widget.authToken);
  }

  void _loadUserData() {
    _userStore.fetchUserById(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _userStore,
        builder: (context, child) {
          if (_userStore.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_userStore.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading User Data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userStore.errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!_userStore.isUserLoaded) {
            return const Center(
              child: Text('No user data available'),
            );
          }

          return _buildUserProfile();
        },
      ),
    );
  }

  Widget _buildUserProfile() {
    final user = _userStore.userDetail!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.company,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip('ID: ${user.id}', Colors.grey),
                      const SizedBox(width: 8),
                      _buildInfoChip('Employee: ${user.employeeId}', Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Service Area
          if (user.serviceArea.isNotEmpty) ...[
            _buildSectionCard(
              'Service Area',
              Icons.work,
              user.serviceArea,
            ),
            const SizedBox(height: 16),
          ],
          
          // Divisions
          if (user.divisions.isNotEmpty) ...[
            _buildSectionCard(
              'Divisions',
              Icons.business,
              _userStore.getDivisionNames().join(', '),
            ),
            const SizedBox(height: 16),
          ],
          
          // User Details
          _buildSectionCard(
            'User Details',
            Icons.person,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Phone', user.phoneNumber),
                _buildDetailRow('Status', user.activeText),
                _buildDetailRow('Last Login', user.lastLoginDateTime ?? 'Never'),
                _buildDetailRow('Date Format', user.dateFormat),
                _buildDetailRow('Currency', user.baseCurrencyText),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Roles
          if (user.roles.isNotEmpty) ...[
            _buildSectionCard(
              'Roles',
              Icons.security,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: user.roles.map((role) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text('• Role ID: ${role.roleId}'),
                  ),
                ).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, dynamic content) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (content is String)
              Text(content)
            else
              content,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  @override
  void dispose() {
    _userStore.dispose();
    super.dispose();
  }
}
