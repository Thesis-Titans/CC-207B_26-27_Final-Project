import 'api_client.dart';

/// Provides caregiver data export and account deletion operations.
class AccountService {
  AccountService({required this.apiClient});

  /// The authenticated client used for account requests.
  final ApiClient apiClient;

  /// Downloads the signed-in caregiver's data as a JSON object.
  Future<Map<String, dynamic>> exportData() async {
    final data = await apiClient.get('/api/v1/me/export');
    if (data is! Map<String, dynamic>) {
      throw FormatException('The data export response was invalid.');
    }
    return data;
  }

  /// Permanently deletes the signed-in caregiver's account and records.
  Future<void> deleteAccount() async {
    await apiClient.delete('/api/v1/me');
  }
}
