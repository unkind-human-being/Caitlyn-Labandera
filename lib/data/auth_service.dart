import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

/// A local, single-admin sign-in gate. Password hashes are not plaintext.
/// This is NOT device encryption or an online account/recovery system.
class AuthService {
  AuthService(this._box);

  final Box<dynamic> _box;
  static const defaultUsername = 'Caitlyn';
  static const defaultPassword = 'caitlyn2026';
  static const _userKey = 'admin_username_v2';
  static const _saltKey = 'admin_salt_v2';
  static const _hashKey = 'admin_hash_v2';

  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 60000,
    bits: 256,
  );

  String get username => _box.get(_userKey, defaultValue: defaultUsername) as String;

  Future<void> initialize() async {
    if (!_box.containsKey(_hashKey)) {
      await _storeCredentials(defaultUsername, defaultPassword);
    }
  }

  Future<List<int>> _derive(String password, List<int> salt) async {
    final key = await _kdf.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }

  Future<bool> authenticate(String username, String password) async {
    if (username.trim() != this.username) return false;
    final saltEncoded = _box.get(_saltKey);
    final hashEncoded = _box.get(_hashKey);
    if (saltEncoded is! String || hashEncoded is! String) return false;
    try {
      final derived = await _derive(password, base64Decode(saltEncoded));
      final expected = base64Decode(hashEncoded);
      if (expected.length != derived.length) return false;
      var mismatch = 0;
      for (var i = 0; i < expected.length; i++) {
        mismatch |= expected[i] ^ derived[i];
      }
      return mismatch == 0;
    } catch (_) {
      return false;
    }
  }

  /// Requires the current password even when only the username changes.
  /// An empty new password means 'keep current password'.
  Future<bool> changeCredentials({
    required String currentPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    if (newUsername.trim().length < 3 || newUsername.trim().length > 30) {
      throw ArgumentError('Username must have 3 to 30 characters.');
    }
    if (newPassword.isNotEmpty && newPassword.length < 8) {
      throw ArgumentError('New password must have at least 8 characters.');
    }
    if (!await authenticate(username, currentPassword)) return false;
    await _storeCredentials(
      newUsername.trim(),
      newPassword.isEmpty ? currentPassword : newPassword,
    );
    return true;
  }

  Future<void> _storeCredentials(String username, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final derived = await _derive(password, salt);
    await _box.putAll({
      _userKey: username,
      _saltKey: base64Encode(salt),
      _hashKey: base64Encode(derived),
    });
  }
}
