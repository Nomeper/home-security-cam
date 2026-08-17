import 'package:flutter_test/flutter_test.dart';
import 'package:home_security_cam/app_launch.dart';
import 'package:home_security_cam/utils.dart';

void main() {
  group('DeviceRole helpers', () {
    test('restores a persisted camera role', () {
      expect(stringToRole(DeviceRole.camera3.toString()), DeviceRole.camera3);
    });

    test('falls back to viewer for missing or invalid roles', () {
      expect(stringToRole(null), DeviceRole.viewer);
      expect(stringToRole('invalid-role'), DeviceRole.viewer);
    });

    test('maps roles to stable UIDs', () {
      expect(getUidFromRole(DeviceRole.camera1), 10);
      expect(getUidFromRole(DeviceRole.viewer), 100);
    });
  });

  group('Camera name validation', () {
    test('normalizes surrounding and repeated whitespace', () {
      expect(
        normalizeCameraName('  Ingresso   principale  '),
        'Ingresso principale',
      );
    });

    test('rejects empty, control-character and overlong names', () {
      expect(validateCameraName(''), isNotNull);
      expect(validateCameraName('Ingresso\nprincipale'), isNotNull);
      expect(validateCameraName('a' * 33), isNotNull);
    });

    test('accepts a valid normalized name', () {
      expect(validateCameraName(normalizeCameraName(' Garage ')), isNull);
    });
  });

  group('App launch', () {
    test('asks for App ID first', () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: false,
          isDeviceOwner: false,
          role: null,
        ),
        AppLaunchRoute.appId,
      );
    });

    test('Device Owner skips role selection after App ID', () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: true,
          isDeviceOwner: true,
          role: null,
        ),
        AppLaunchRoute.security,
      );
    });

    test('viewer phones still choose a role', () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: true,
          isDeviceOwner: false,
          role: null,
        ),
        AppLaunchRoute.roleSelection,
      );
    });
  });
}
