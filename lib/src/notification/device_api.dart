import '../network/api_client.dart';

/// Registers/unregisters this device's FCM token with the backend so the user
/// receives push notifications. Mirrors the backend `DeviceRegisterRequest`.
class DeviceApi {
  final ApiClient apiClient;

  DeviceApi(this.apiClient);

  Future<void> registerToken(String token, {String platform = 'ANDROID'}) async {
    await apiClient.post('/api/devices', body: {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> unregister(String token) async {
    await apiClient.delete('/api/devices', body: {'token': token});
  }
}
