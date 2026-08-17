// lib/utils.dart

const String kChannelName = 'casa_sicura';
const List<int> kCamUids = [10, 20, 30, 40, 50, 60];
const int kViewerUid = 100;

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
