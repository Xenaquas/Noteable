import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isBiometricAvailable async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to proceed',
    bool biometricOnly = false,
  }) async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!isDeviceSupported) {
        // No biometric support available
        return false;
      }

      // Use the simple API compatible with local_auth 3.x
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: false,
        biometricOnly: biometricOnly,
      );
    } catch (_) {
      return false;
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
