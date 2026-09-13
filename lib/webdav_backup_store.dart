import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as dav;

import 'i18n.dart';

class WebdavBackupStore {
  final dav.Client _client;

  WebdavBackupStore(String url, String username, String password)
      : _client = _createClient(url, username, password);

  static dav.Client _createClient(
      String url, String username, String password) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid WebDAV URL');
    }
    return dav.newClient(uri.toString(),
        user: username.trim(), password: password)
      ..setConnectTimeout(15000)
      ..setSendTimeout(120000)
      ..setReceiveTimeout(120000);
  }

  // OPTIONS can succeed even when the configured directory does not exist.
  Future<void> testConnection() async {
    await _client.readDir('/');
  }

  Future<List<dav.File>> listBackups() async {
    await testConnection();
    try {
      final files = await _client.readDir('/moetalk/');
      return files
          .where((file) =>
              file.isDir != true &&
              (file.name?.toLowerCase().endsWith('.json') ?? false))
          .toList()
        ..sort((a, b) => b.name!.compareTo(a.name!));
    } on DioException catch (error) {
      // A valid account with no backups yet has no app directory.
      if (error.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  String _path(String name) {
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        !name.toLowerCase().endsWith('.json')) {
      throw const FormatException('Invalid backup filename');
    }
    return '/moetalk/${Uri.encodeComponent(name)}';
  }

  Future<void> write(String name, String content,
      {void Function(int, int)? onProgress}) async {
    final path = _path(name);
    await testConnection();
    await _client.mkdir('/moetalk/');
    await _client.write(path, utf8.encode(content), onProgress: onProgress);
  }

  Future<String> read(String name,
      {void Function(int, int)? onProgress}) async {
    return utf8.decode(await _client.read(_path(name), onProgress: onProgress));
  }

  void close() => _client.c.close(force: true);
}

// Avoid including request URLs, credentials or backup contents in UI errors.
String webdavErrorMessage(Object error) {
  if (error is FormatException) return I18n.t('webdav_invalid_data');
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return I18n.t('webdav_auth_failed');
    if (status == 403) return I18n.t('webdav_forbidden');
    if (status == 404 || status == 409) {
      return I18n.t('webdav_directory_missing');
    }
    if (status != null) return 'HTTP $status';
    return I18n.t('webdav_network_error');
  }
  return I18n.t('webdav_operation_failed');
}
