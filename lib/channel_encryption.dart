import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:crypto/crypto.dart';

/// Passphrase salvata in locale (stesso posto dell’App ID). Non è un token Agora.
const String kChannelKeyPref = 'agora_channel_key';
const int kMinChannelKeyLength = 8;

/// Il visore Web Agora cifra la chiave con RSA-1024 prima del join (~62 byte max).
const int kMaxChannelKeyUtf8Length = 62;

const String kChannelSaltPrefix = 'hsc-v1-salt:';

class ChannelEncryptionMaterial {
  const ChannelEncryptionMaterial({required this.key, required this.salt});

  final String key;
  final Uint8List salt;
}

int channelKeyUtf8Length(String value) => utf8.encode(value.trim()).length;

bool isValidChannelKey(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length < kMinChannelKeyLength) return false;
  return channelKeyUtf8Length(trimmed) <= kMaxChannelKeyUtf8Length;
}

String? validateChannelKey(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length < kMinChannelKeyLength) {
    return 'Inserisci almeno $kMinChannelKeyLength caratteri.';
  }
  if (channelKeyUtf8Length(trimmed) > kMaxChannelKeyUtf8Length) {
    return 'Massimo $kMaxChannelKeyUtf8Length caratteri (limite del visore PC).';
  }
  return null;
}

/// Chiave = passphrase; salt = SHA-256 con prefisso fisso (identico su Dart e JS).
ChannelEncryptionMaterial deriveChannelEncryption(String passphrase) {
  final trimmed = passphrase.trim();
  final validationError = validateChannelKey(trimmed);
  if (validationError != null) {
    throw ArgumentError(validationError);
  }
  final saltDigest = sha256.convert(utf8.encode('$kChannelSaltPrefix$trimmed'));
  return ChannelEncryptionMaterial(
    key: trimmed,
    salt: Uint8List.fromList(saltDigest.bytes),
  );
}

EncryptionConfig agoraEncryptionConfig(String passphrase) {
  final material = deriveChannelEncryption(passphrase);
  return EncryptionConfig(
    encryptionMode: EncryptionMode.aes256Gcm2,
    encryptionKey: material.key,
    encryptionKdfSalt: material.salt,
    datastreamEncryptionEnabled: true,
  );
}

Future<void> enableChannelEncryption(
  RtcEngine engine,
  String passphrase,
) {
  return engine.enableEncryption(
    enabled: true,
    config: agoraEncryptionConfig(passphrase),
  );
}
