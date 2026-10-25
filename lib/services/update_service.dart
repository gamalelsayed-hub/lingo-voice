import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _releaseBase =
    'https://github.com/gamalelsayed-hub/lingo-voice/releases/download/latest';

/// A newer build published by GitHub Actions.
class AppUpdate {
  AppUpdate({required this.build, required this.sha256});

  final int build;
  final String? sha256;
}

/// Checks the "latest" GitHub release for a newer APK and installs it.
class UpdateService {
  UpdateService._();

  static final instance = UpdateService._();

  /// Returns the newer build, or null when the app is up to date.
  Future<AppUpdate?> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;
    final response = await http
        .get(Uri.parse('$_releaseBase/version.json'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = json['build'] as int;
    if (latest <= current) return null;
    return AppUpdate(build: latest, sha256: json['sha256'] as String?);
  }

  /// Downloads the APK and opens Android's installer. Android always asks
  /// the user to confirm, and the first time to allow installs from this app.
  Stream<OtaEvent> install(AppUpdate update) => OtaUpdate().execute(
    '$_releaseBase/app-release.apk',
    destinationFilename: 'lingo-voice-${update.build}.apk',
    sha256checksum: update.sha256,
  );
}
