import 'package:flutter/material.dart';
import 'package:boilerplate/presentation/user/user_profile_screen.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/core/data/network/dio/configs/dio_configs.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';

/// Example of how to integrate the user API in your presentation layer
class UserIntegrationExample extends StatelessWidget {
  const UserIntegrationExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User API Integration Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'User API Integration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates how to use the user API with bearer token authentication.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Example usage cards
            _buildExampleCard(
              'Load User Profile',
              'Navigate to user profile with ID 40',
              Icons.person,
              () => _navigateToUserProfile(context, 40),
            ),
            
            const SizedBox(height: 16),
            
            _buildExampleCard(
              'API Endpoint',
              'https://103.141.54.146:1445/erpapi/api/User/Get?Id=40',
              Icons.link,
              () => _showApiInfo(context),
            ),
            
            const SizedBox(height: 16),
            
            _buildExampleCard(
              'Authentication',
              'Uses Bearer Token for API authentication',
              Icons.security,
              () => _showAuthInfo(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleCard(String title, String description, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[600]),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  void _navigateToUserProfile(BuildContext context, int userId) {
    // In a real app, you would get the auth token from your authentication store
    const String authToken = 'your_bearer_token_here';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          authToken: authToken,
          userId: userId,
        ),
      ),
    );
  }

  void _showApiInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Endpoint'),
        content: const Text(
          'GET https://103.141.54.146:1445/erpapi/api/User/Get?Id=40\n\n'
          'Headers:\n'
          'Authorization: Bearer {your_token}\n'
          'Content-Type: application/json',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAuthInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication'),
        content: const Text(
          'The API requires Bearer token authentication.\n\n'
          'Make sure to:\n'
          '1. Obtain a valid bearer token from your login process\n'
          '2. Pass the token to the UserStore\n'
          '3. The token will be automatically included in API requests',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Example of how to use the UserStore in your widgets
class UserStoreUsageExample extends StatefulWidget {
  const UserStoreUsageExample({Key? key}) : super(key: key);

  @override
  State<UserStoreUsageExample> createState() => _UserStoreUsageExampleState();
}

class _UserStoreUsageExampleState extends State<UserStoreUsageExample> {
  // This would typically be injected through dependency injection
  // For this example, we'll show the pattern
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UserStore Usage Example'),
      ),
      body: const Center(
        child: Text(
          'This example shows how to use UserStore in your widgets.\n\n'
          '1. Inject UserStore through dependency injection\n'
          '2. Use Observer widget to listen to store changes\n'
          '3. Call store methods to fetch user data\n'
          '4. Access computed properties for UI updates',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
