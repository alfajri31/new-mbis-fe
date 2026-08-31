/// Platform native tidak punya konsep *secure context* — `flutter_secure_storage`
/// di sana memakai Keychain (iOS) / EncryptedSharedPreferences (Android) dan selalu
/// tersedia. Selalu true supaya penelepon tidak perlu membedakan platform.
bool isBrowserSecureContext() => true;
