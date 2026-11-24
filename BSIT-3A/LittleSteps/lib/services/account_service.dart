import 'api_client.dart';

/// Caregiver data export and account deletion operations.
class AccountService {
  AccountService({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> exportData() async {
    final data = await apiClient.get('/api/v1/me/export');
    if (data is! Map<String, dynamic>) {
      throw FormatException('The data export response was invalid.');
    }
    return data;
  }

  Future<void> deleteAccount() async {
    await apiClient.delete('/api/v1/me');
  }
}
