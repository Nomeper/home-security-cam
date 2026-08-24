import 'package:flutter_test/flutter_test.dart';
import 'package:home_security_cam/app_launch.dart';
import 'package:home_security_cam/channel_encryption.dart';
import 'package:home_security_cam/services/startup_permissions.dart';
import 'package:home_security_cam/utils.dart';
import 'package:permission_handler/permission_handler.dart';

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

    test('publishes camera video only when selected by a present viewer', () {
      expect(
        shouldPublishCameraVideo(
          viewerPresent: false,
          selectedByViewer: true,
        ),
        isFalse,
      );
      expect(
        shouldPublishCameraVideo(
          viewerPresent: true,
          selectedByViewer: false,
        ),
        isFalse,
      );
      expect(
        shouldPublishCameraVideo(
          viewerPresent: true,
          selectedByViewer: true,
        ),
        isTrue,
      );
      expect(
        shouldCaptureCameraHardware(
          viewerPresent: false,
          selectedByViewer: true,
        ),
        isFalse,
      );
      expect(
        shouldCaptureCameraHardware(
          viewerPresent: true,
          selectedByViewer: true,
        ),
        isTrue,
      );
      expect(isViewerUid(kViewerUid), isTrue);
      expect(isViewerUid(kCamUids.first), isFalse);
      expect(isRemoteViewerUid(kViewerUid), isTrue);
      expect(isRemoteViewerUid(12345), isTrue);
      expect(isRemoteViewerUid(kCamUids.first), isFalse);
      expect(isRemoteViewerUid(0), isFalse);
      expect(isRemoteViewerUid(kPcViewerUid), isTrue);
      expect(isRemoteViewerUid(kRoleProbeUidMin), isFalse);
      expect(isRemoteViewerUid(kRoleProbeUidMax), isFalse);
      expect(isRoleProbeUid(195), isTrue);
      expect(isRoleProbeUid(kViewerUid), isFalse);
    });

    test('occupies CAM and visor roles from live channel UIDs', () {
      expect(roleOccupiedByUid(10), DeviceRole.camera1);
      expect(roleOccupiedByUid(60), DeviceRole.camera6);
      expect(roleOccupiedByUid(kViewerUid), DeviceRole.viewer);
      expect(roleOccupiedByUid(kPcViewerUid), DeviceRole.viewer);
      expect(roleOccupiedByUid(12345), DeviceRole.viewer);
      expect(roleOccupiedByUid(195), isNull);
      expect(
        occupiedRolesFromUids({10, 100, 199}),
        {DeviceRole.camera1, DeviceRole.viewer},
      );
      expect(
        occupiedRolesFromUids({101, 20, 30}),
        {DeviceRole.viewer, DeviceRole.camera2, DeviceRole.camera3},
      );
      expect(occupiedRolesFromUids({199}), isEmpty);
    });
  });

  group('Watch command', () {
    test('encodes selected camera UIDs in stable order', () {
      expect(encodeWatchCommand({30, 10}), 'WATCH:10,30');
      expect(encodeWatchCommand(const <int>[]), 'WATCH:');
      expect(encodeWatchCommand({99, 10}), 'WATCH:10');
    });

    test('parses valid camera UIDs and ignores junk', () {
      expect(parseWatchCommand('WATCH:10,20'), {10, 20});
      expect(parseWatchCommand('WATCH:'), isEmpty);
      expect(parseWatchCommand('WATCH:10,99,20'), {10, 20});
      expect(parseWatchCommand('FLASH'), isEmpty);
      expect(isWatchCommand('WATCH:10'), isTrue);
      expect(isWatchCommand(kFlashCommand), isFalse);
    });

    test('lays out the viewer grid by count and orientation', () {
      expect(
        viewerGridColumnCount(selectedCount: 1, landscape: false),
        1,
      );
      expect(
        viewerGridColumnCount(selectedCount: 2, landscape: false),
        1,
      );
      expect(
        viewerGridColumnCount(selectedCount: 2, landscape: true),
        2,
      );
      expect(
        viewerGridColumnCount(selectedCount: 4, landscape: false),
        2,
      );
    });

    test('treats camera frames as portrait or landscape from size and rotation',
        () {
      expect(
        isOrientedVideoPortrait(width: 720, height: 1280),
        isTrue,
      );
      expect(
        isOrientedVideoPortrait(width: 1280, height: 720),
        isFalse,
      );
      expect(
        isOrientedVideoPortrait(width: 1280, height: 720, rotation: 90),
        isTrue,
      );
      expect(
        orientedVideoSize(width: 1280, height: 720, rotation: 90),
        (width: 720, height: 1280),
      );
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

  group('Remote control commands', () {
    test('encodes and parses targeted flash commands', () {
      expect(encodeFlashCommand(10, FlashAction.on), 'FLASH:10:ON');
      expect(parseFlashCommand('FLASH:20:OFF')?.targetUid, 20);
      expect(parseFlashCommand('FLASH')?.action, FlashAction.toggle);
      expect(parseFlashCommand('FLASH:99:ON'), isNull);
    });

    test('encodes and parses battery reports', () {
      expect(encodeBatteryReport(30, 85), 'BATT:30:85');
      expect(parseBatteryReport('BATT:30:85'), (30, 85));
      expect(parseBatteryReport('BATT:30:150'), (30, 100));
      expect(isBatteryRequest('BATTREQ'), isTrue);
      expect(isBatteryRequest('BATT:10:80'), isFalse);
    });

    test('encodes and parses listen commands', () {
      expect(encodeListenCommand(40, true), 'LISTEN:40:ON');
      expect(parseListenCommand('LISTEN:40:OFF')?.enabled, isFalse);
    });

    test('encodes and parses lens commands', () {
      expect(encodeLensCommand(10, CameraLens.front), 'LENS:10:FRONT');
      expect(parseLensCommand('LENS:20:REAR')?.lens, CameraLens.rear);
      expect(parseLensCommand('LENS:10:FRONT')?.targetUid, 10);
      expect(parseLensCommand('LENS:99:FRONT'), isNull);
      expect(encodeLensState(30, CameraLens.rear), 'LENSSTATE:30:REAR');
      expect(parseLensState('LENSSTATE:50:FRONT'), (50, CameraLens.front));
    });

    test('keeps the camera screen on only while capturing and not in ECO', () {
      expect(shouldKeepCameraAwake(capturing: false), isFalse);
      expect(shouldKeepCameraAwake(capturing: true), isTrue);
      expect(shouldKeepCameraAwake(capturing: true, ecoMode: true), isFalse);
      expect(shouldKeepCameraAwake(capturing: false, ecoMode: true), isFalse);
      expect(
        shouldKeepCameraAwake(
          capturing: true,
          ecoMode: true,
          screenFlashOn: true,
        ),
        isTrue,
      );
      expect(
        shouldKeepCameraAwake(
          capturing: false,
          ecoMode: true,
          screenFlashOn: true,
        ),
        isTrue,
      );
      expect(usesScreenAsFlash(frontCamera: true), isTrue);
      expect(usesScreenAsFlash(frontCamera: false), isFalse);
      expect(
        cameraStandbyScreenOffMessage(15),
        'Fotocamera spenta. Lo schermo si spegnerà fra 15s',
      );
      expect(
        cameraStandbyScreenOffMessage(0),
        'Fotocamera spenta. Lo schermo si spegnerà fra 0s',
      );
      expect(
        shouldHideCameraChromeForDisplaySleep(displayAsleep: true),
        isTrue,
      );
      expect(
        shouldHideCameraChromeForDisplaySleep(displayAsleep: false),
        isFalse,
      );
      expect(
        shouldShowLocalCameraPreview(
          capturing: true,
          ecoMode: false,
          displayAsleep: false,
        ),
        isTrue,
      );
      expect(
        shouldShowLocalCameraPreview(
          capturing: true,
          ecoMode: true,
          displayAsleep: false,
        ),
        isFalse,
      );
    });

    test('encodes and parses flash state updates', () {
      expect(encodeFlashState(50, true), 'FLASHSTATE:50:ON');
      expect(parseFlashState('FLASHSTATE:50:OFF'), (50, false));
    });

    test('treats BYE as the visore leaving the channel', () {
      expect(isViewerLeaveCommand('BYE'), isTrue);
      expect(isViewerLeaveCommand('WATCH:'), isFalse);
      expect(kViewerLeaveCommand, 'BYE');
    });
  });

  group('App launch', () {
    test('asks for App ID first', () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: false,
          hasChannelKey: false,
          isDeviceOwner: false,
        ),
        AppLaunchRoute.appId,
      );
    });

    test('asks for the house key even if App ID is already saved', () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: true,
          hasChannelKey: false,
          isDeviceOwner: false,
        ),
        AppLaunchRoute.appId,
      );
    });

    test('Device Owner skips role selection after App ID and house key', () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: true,
          hasChannelKey: true,
          isDeviceOwner: true,
        ),
        AppLaunchRoute.security,
      );
    });

    test('phones always open on role selection, even with a saved visor role',
        () {
      expect(
        AppLaunchDecision.decide(
          hasAppId: true,
          hasChannelKey: true,
          isDeviceOwner: false,
        ),
        AppLaunchRoute.roleSelection,
      );
    });
  });

  group('Channel encryption', () {
    test('rejects short or overlong house keys', () {
      expect(isValidChannelKey(null), isFalse);
      expect(isValidChannelKey(''), isFalse);
      expect(isValidChannelKey('1234567'), isFalse);
      expect(isValidChannelKey('  casa12 '), isFalse);
      expect(isValidChannelKey('casa1234'), isTrue);
      expect(isValidChannelKey('a' * 63), isFalse);
      expect(isValidChannelKey('a' * 62), isTrue);
    });

    test('uses the passphrase as key and derives a 32-byte salt', () {
      final material = deriveChannelEncryption('casa1234');
      expect(material.key, 'casa1234');
      expect(material.salt.length, 32);
      expect(
        material.salt
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
        'aebafee0f112c8dcb51285a012b56445b39e6dbe239f64e463a1e6c738831d45',
      );
    });

    test('trims the passphrase before use', () {
      expect(
        deriveChannelEncryption('  casa1234  ').key,
        'casa1234',
      );
    });
  });

  group('Startup permissions', () {
    test('asks for camera, microphone and notifications at launch', () {
      expect(
        StartupPermissions.runtime,
        containsAll([
          Permission.camera,
          Permission.microphone,
          Permission.notification,
        ]),
      );
      expect(
        StartupPermissions.runtime,
        isNot(contains(Permission.bluetoothConnect)),
      );
    });
  });

  group('Viewer top bar', () {
    test('camera chrome stays visible so status is always readable', () {
      expect(shouldKeepSecurityChromeVisible(isCamera: true), isTrue);
      expect(shouldKeepSecurityChromeVisible(isCamera: false), isFalse);
    });
  });

  group('Transmission indicator', () {
    test('is green only while video data is moving', () {
      expect(
        isDataTransmitting(
          isCamera: true,
          cameraPublishing: true,
          viewerReceivingVideo: false,
        ),
        isTrue,
      );
      expect(
        isDataTransmitting(
          isCamera: true,
          cameraPublishing: false,
          viewerReceivingVideo: true,
        ),
        isFalse,
      );
      expect(
        isDataTransmitting(
          isCamera: false,
          cameraPublishing: false,
          viewerReceivingVideo: true,
        ),
        isTrue,
      );
      expect(
        isDataTransmitting(
          isCamera: false,
          cameraPublishing: true,
          viewerReceivingVideo: false,
        ),
        isFalse,
      );
    });
  });
}
