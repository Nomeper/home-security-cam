import 'package:flutter_test/flutter_test.dart';
import 'package:home_security_cam/services/rtc_session_service.dart';
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

    test('uses predictable display names', () {
      expect(getDefaultNameForRole(DeviceRole.camera1), 'CAM 1');
      expect(getDefaultNameForRole(DeviceRole.camera6), 'CAM 6');
      expect(getDefaultNameForRole(DeviceRole.viewer), 'Visore');
    });
  });

  group('Camera name validation', () {
    test('normalizes surrounding and repeated whitespace', () {
      expect(normalizeCameraName('  Ingresso   principale  '), 'Ingresso principale');
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

  group('RtcSession', () {
    test('parses a complete server response', () {
      final session = RtcSession.fromMap({
        'appId': 'public-app-id',
        'channelId': 'home_abc',
        'expiresAt': 1735689600,
        'role': 'viewer',
        'token': 'temporary-token',
        'uid': 42,
      });

      expect(session.channelId, 'home_abc');
      expect(session.role, 'viewer');
      expect(session.uid, 42);
      expect(session.expiresAt, DateTime.fromMillisecondsSinceEpoch(1735689600000));
    });

    test('rejects an incomplete server response', () {
      expect(
        () => RtcSession.fromMap({
          'appId': 'public-app-id',
          'channelId': 'home_abc',
          'expiresAt': 'not-a-timestamp',
        }),
        throwsFormatException,
      );
    });
  });
}
