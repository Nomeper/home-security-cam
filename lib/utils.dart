// lib/utils.dart

// Definizione dei Ruoli
enum DeviceRole { camera1, camera2, camera3, camera4, camera5, camera6, viewer }

// Helper: Converte stringa salvata in Ruolo
DeviceRole stringToRole(String? s) {
  if (s == null) return DeviceRole.viewer;
  return DeviceRole.values.firstWhere(
    (e) => e.toString() == s,
    orElse: () => DeviceRole.viewer,
  );
}

// Helper: Ottieni nome di default per il ruolo
String getDefaultNameForRole(DeviceRole role) {
  if (role == DeviceRole.viewer) return "Visore";
  int index = DeviceRole.values.indexOf(role) + 1;
  return "CAM $index";
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

