// lib/utils.dart

const String kChannelName = 'casa_sicura';
const List<int> kCamUids = [10, 20, 30, 40, 50, 60];
const int kViewerUid = 100;
const int kPcViewerUid = 101;
/// UID usati solo dalla schermata «Scegli ruolo» per vedere chi è già nel
/// canale, senza pubblicare video e senza fingere un visore.
const int kRoleProbeUidMin = 190;
const int kRoleProbeUidMax = 199;
// Visore PC in web-viewer/: UID 101. Le camere trattano qualsiasi UID
// non-camera (tranne i probe) come visore (isRemoteViewerUid).
const String kWatchCommandPrefix = 'WATCH:';
const String kFlashCommand = 'FLASH';
const String kFlashCommandPrefix = 'FLASH:';
const String kFlashStateCommandPrefix = 'FLASHSTATE:';
const String kBatteryCommandPrefix = 'BATT:';
const String kBatteryRequestCommand = 'BATTREQ';
const String kListenCommandPrefix = 'LISTEN:';
const String kLensCommandPrefix = 'LENS:';
const String kLensStateCommandPrefix = 'LENSSTATE:';
const String kViewerLeaveCommand = 'BYE';
const Duration kViewerHeartbeatInterval = Duration(seconds: 4);
const Duration kViewerPresenceTimeout = Duration(seconds: 12);
const Duration kCameraStandbyScreenTimeout = Duration(seconds: 15);
const String kAgoraWebsiteUrl = 'https://www.agora.io/';

enum CameraLens { rear, front }

enum FlashAction { on, off, toggle }

class FlashCommand {
  final int? targetUid;
  final FlashAction action;

  const FlashCommand({required this.targetUid, required this.action});
}

class ListenCommand {
  final int targetUid;
  final bool enabled;

  const ListenCommand({required this.targetUid, required this.enabled});
}

class LensCommand {
  final int targetUid;
  final CameraLens lens;

  const LensCommand({required this.targetUid, required this.lens});
}

enum DeviceRole { camera1, camera2, camera3, camera4, camera5, camera6, viewer }

DeviceRole stringToRole(String? s) {
  if (s == null) return DeviceRole.viewer;
  return DeviceRole.values.firstWhere(
    (e) => e.toString() == s,
    orElse: () => DeviceRole.viewer,
  );
}

String getDefaultNameForRole(DeviceRole role) {
  if (role == DeviceRole.viewer) return 'Visore';
  int index = DeviceRole.values.indexOf(role) + 1;
  return 'CAM $index';
}

int getUidFromRole(DeviceRole role) {
  if (role == DeviceRole.viewer) return kViewerUid;
  return kCamUids[DeviceRole.values.indexOf(role)];
}

bool isViewerUid(int uid) => uid == kViewerUid;

bool isRoleProbeUid(int uid) =>
    uid >= kRoleProbeUidMin && uid <= kRoleProbeUidMax;

int randomRoleProbeUid() {
  const span = kRoleProbeUidMax - kRoleProbeUidMin + 1;
  return kRoleProbeUidMin + DateTime.now().microsecondsSinceEpoch % span;
}

/// In live broadcast Agora non notifica i client audience. Qualsiasi UID
/// remoto che non è una camera viene trattato come visore (anche se Agora
/// riassegna l’UID 100 in assenza di token). I probe della schermata ruoli
/// restano fuori, così non svegliano le camere.
bool isRemoteViewerUid(int uid) =>
    uid > 0 && !kCamUids.contains(uid) && !isRoleProbeUid(uid);

DeviceRole? roleOccupiedByUid(int uid) {
  if (isRemoteViewerUid(uid)) return DeviceRole.viewer;
  final cameraIndex = kCamUids.indexOf(uid);
  if (cameraIndex < 0) return null;
  return DeviceRole.values[cameraIndex];
}

Set<DeviceRole> occupiedRolesFromUids(Iterable<int> uids) => {
      for (final uid in uids)
        if (roleOccupiedByUid(uid) case final role?) role,
    };

bool isWatchCommand(String message) => message.startsWith(kWatchCommandPrefix);

String encodeWatchCommand(Iterable<int> uids) {
  final selected = uids.where(kCamUids.contains).toSet().toList()..sort();
  return '$kWatchCommandPrefix${selected.join(',')}';
}

Set<int> parseWatchCommand(String message) {
  if (!isWatchCommand(message)) return {};
  final payload = message.substring(kWatchCommandPrefix.length).trim();
  if (payload.isEmpty) return {};
  return payload
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .where(kCamUids.contains)
      .toSet();
}

/// Le telecamere inviano video solo se il visore è presente e la camera
/// è selezionata nella griglia. La modalità eco oscura solo lo schermo
/// locale e non interrompe la trasmissione.
bool shouldPublishCameraVideo({
  required bool viewerPresent,
  required bool selectedByViewer,
}) =>
    viewerPresent && selectedByViewer;

/// Il sensore fotocamera sta acceso solo mentre si pubblica. In attesa
/// visore (anche in ECO) resta spento in standby.
bool shouldCaptureCameraHardware({
  required bool viewerPresent,
  required bool selectedByViewer,
}) =>
    shouldPublishCameraVideo(
      viewerPresent: viewerPresent,
      selectedByViewer: selectedByViewer,
    );

/// Pallino verde = dati video in transito; rosso = nessuna trasmissione.
bool isDataTransmitting({
  required bool isCamera,
  required bool cameraPublishing,
  required bool viewerReceivingVideo,
}) =>
    isCamera ? cameraPublishing : viewerReceivingVideo;

/// Flash sulla frontale: lo schermo fa da torcia. Sulla posteriore si usa
/// il LED. Stesso comando FLASH del visore in entrambi i casi.
bool usesScreenAsFlash({required bool frontCamera}) => frontCamera;

/// In standby o in ECO il telefono camera non tiene lo schermo sempre acceso.
/// Resta nel canale Agora così il visore lo sveglia subito con WATCH:.
/// Il flash a schermo (frontale) tiene acceso e sveglia anche in ECO.
bool shouldKeepCameraAwake({
  required bool capturing,
  bool ecoMode = false,
  bool screenFlashOn = false,
}) =>
    screenFlashOn || (capturing && !ecoMode);

String cameraStandbyScreenOffMessage(int secondsLeft) {
  final seconds = secondsLeft < 0 ? 0 : secondsLeft;
  return 'Fotocamera spenta. Lo schermo si spegnerà fra ${seconds}s';
}

/// A 0s non resta nessuna scritta: overlay nero (e su kiosk spegnimento pannello).
bool shouldHideCameraChromeForDisplaySleep({required bool displayAsleep}) =>
    displayAsleep;

/// In ECO/standby-schermo non montare la preview locale (SurfaceView Android
/// passa sopra l’overlay Flutter e lascia visibile il pallino/preview).
bool shouldShowLocalCameraPreview({
  required bool capturing,
  required bool ecoMode,
  required bool displayAsleep,
}) =>
    capturing && !ecoMode && !displayAsleep;

/// Sulla telecamera menu e stato restano sempre visibili. Sul visore
/// appaiono e restano al tap, e spariscono al tap successivo.
bool shouldKeepSecurityChromeVisible({required bool isCamera}) => isCamera;

int viewerGridColumnCount({
  required int selectedCount,
  required bool landscape,
}) {
  if (selectedCount <= 1) return 1;
  if (selectedCount == 2) return landscape ? 2 : 1;
  return 2;
}

({int width, int height}) orientedVideoSize({
  required int width,
  required int height,
  int rotation = 0,
}) {
  final turns = ((rotation % 360) + 360) % 360;
  final swapped = turns == 90 || turns == 270;
  return swapped
      ? (width: height, height: width)
      : (width: width, height: height);
}

bool isOrientedVideoPortrait({
  required int width,
  required int height,
  int rotation = 0,
}) {
  final size = orientedVideoSize(
    width: width,
    height: height,
    rotation: rotation,
  );
  return size.height > size.width;
}

String normalizeCameraName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validateCameraName(String value) {
  if (value.isEmpty) return 'Inserisci un nome per la telecamera.';
  if (value.length > 32) {
    return 'Il nome può contenere al massimo 32 caratteri.';
  }
  if (RegExp(r'[\r\n\t]').hasMatch(value)) {
    return 'Il nome non può contenere caratteri di controllo.';
  }
  return null;
}

String encodeFlashCommand(int uid, FlashAction action) {
  final actionName = switch (action) {
    FlashAction.on => 'ON',
    FlashAction.off => 'OFF',
    FlashAction.toggle => 'TOGGLE',
  };
  return '$kFlashCommandPrefix$uid:$actionName';
}

FlashCommand? parseFlashCommand(String message) {
  if (message == kFlashCommand) {
    return const FlashCommand(targetUid: null, action: FlashAction.toggle);
  }
  if (!message.startsWith(kFlashCommandPrefix)) return null;
  final parts = message.split(':');
  if (parts.length != 3) return null;
  final uid = int.tryParse(parts[1]);
  if (uid == null || !kCamUids.contains(uid)) return null;
  final action = switch (parts[2].toUpperCase()) {
    'ON' => FlashAction.on,
    'OFF' => FlashAction.off,
    'TOGGLE' => FlashAction.toggle,
    _ => null,
  };
  if (action == null) return null;
  return FlashCommand(targetUid: uid, action: action);
}

String encodeFlashState(int uid, bool isOn) =>
    '$kFlashStateCommandPrefix$uid:${isOn ? 'ON' : 'OFF'}';

(int uid, bool isOn)? parseFlashState(String message) {
  if (!message.startsWith(kFlashStateCommandPrefix)) return null;
  final parts = message.split(':');
  if (parts.length != 3) return null;
  final uid = int.tryParse(parts[1]);
  if (uid == null || !kCamUids.contains(uid)) return null;
  return switch (parts[2].toUpperCase()) {
    'ON' => (uid, true),
    'OFF' => (uid, false),
    _ => null,
  };
}

String encodeBatteryReport(int uid, int level) =>
    '$kBatteryCommandPrefix$uid:${level.clamp(0, 100)}';

(int uid, int level)? parseBatteryReport(String message) {
  if (!message.startsWith(kBatteryCommandPrefix)) return null;
  final parts = message.split(':');
  if (parts.length != 3) return null;
  final uid = int.tryParse(parts[1]);
  final level = int.tryParse(parts[2]);
  if (uid == null || level == null || !kCamUids.contains(uid)) return null;
  return (uid, level.clamp(0, 100));
}

bool isBatteryRequest(String message) =>
    message.trim() == kBatteryRequestCommand;

String encodeListenCommand(int uid, bool enabled) =>
    '$kListenCommandPrefix$uid:${enabled ? 'ON' : 'OFF'}';

ListenCommand? parseListenCommand(String message) {
  if (!message.startsWith(kListenCommandPrefix)) return null;
  final parts = message.split(':');
  if (parts.length != 3) return null;
  final uid = int.tryParse(parts[1]);
  if (uid == null || !kCamUids.contains(uid)) return null;
  final enabled = switch (parts[2].toUpperCase()) {
    'ON' => true,
    'OFF' => false,
    _ => null,
  };
  if (enabled == null) return null;
  return ListenCommand(targetUid: uid, enabled: enabled);
}

String _lensToken(CameraLens lens) =>
    lens == CameraLens.front ? 'FRONT' : 'REAR';

CameraLens? _parseLensToken(String value) => switch (value.toUpperCase()) {
      'FRONT' => CameraLens.front,
      'REAR' => CameraLens.rear,
      _ => null,
    };

String encodeLensCommand(int uid, CameraLens lens) =>
    '$kLensCommandPrefix$uid:${_lensToken(lens)}';

LensCommand? parseLensCommand(String message) {
  if (!message.startsWith(kLensCommandPrefix)) return null;
  final parts = message.split(':');
  if (parts.length != 3) return null;
  final uid = int.tryParse(parts[1]);
  if (uid == null || !kCamUids.contains(uid)) return null;
  final lens = _parseLensToken(parts[2]);
  if (lens == null) return null;
  return LensCommand(targetUid: uid, lens: lens);
}

String encodeLensState(int uid, CameraLens lens) =>
    '$kLensStateCommandPrefix$uid:${_lensToken(lens)}';

(int uid, CameraLens lens)? parseLensState(String message) {
  if (!message.startsWith(kLensStateCommandPrefix)) return null;
  final parts = message.split(':');
  if (parts.length != 3) return null;
  final uid = int.tryParse(parts[1]);
  if (uid == null || !kCamUids.contains(uid)) return null;
  final lens = _parseLensToken(parts[2]);
  if (lens == null) return null;
  return (uid, lens);
}

bool isViewerLeaveCommand(String message) =>
    message.trim() == kViewerLeaveCommand;
