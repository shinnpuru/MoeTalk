import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moetalk/i18n.dart';
import 'package:moetalk/webdav_backup_store.dart';

void main() {
  late HttpServer server;
  late WebdavBackupStore store;
  late Future<void> serving;
  late List<String> requests;
  late Map<String, String> files;
  late bool baseExists;
  late bool backupsExist;
  late bool denyAuthentication;

  String listing(String path) {
    String entry(String href, bool directory) => '''
      <d:response><d:href>$href</d:href><d:propstat><d:prop>
      <d:resourcetype>${directory ? '<d:collection/>' : ''}</d:resourcetype>
      </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>''';
    return '<d:multistatus xmlns:d="DAV:">${entry(path, true)}'
        '${path == '/dav/talk/moetalk/' ? files.keys.map((name) => entry('$path${Uri.encodeComponent(name)}', false)).join() : ''}'
        '</d:multistatus>';
  }

  setUp(() async {
    I18n.locale = 'en';
    requests = [];
    files = {};
    baseExists = true;
    backupsExist = false;
    denyAuthentication = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serving = () async {
      await for (final request in server) {
        final path = request.uri.path;
        requests.add('${request.method} $path');
        final response = request.response;
        if (denyAuthentication ||
            request.headers.value('authorization') !=
                'Basic ${base64Encode(utf8.encode('test-user:test-password'))}') {
          response.statusCode = 401;
          response.headers.set('www-authenticate', 'Basic realm="test"');
        } else if (request.method == 'OPTIONS') {
          // Reproduce Nutstore's successful ping for a nonexistent path.
          response.statusCode = 200;
        } else if (!baseExists) {
          response.statusCode = 404;
        } else if (request.method == 'PROPFIND') {
          if (path == '/dav/talk/' || backupsExist) {
            response.statusCode = 207;
            response.headers.contentType = ContentType('application', 'xml');
            response.write(listing(path));
          } else {
            response.statusCode = 404;
          }
        } else if (request.method == 'MKCOL') {
          response.statusCode = backupsExist ? 405 : 201;
          backupsExist = true;
        } else if (request.method == 'PUT') {
          if (!backupsExist) {
            response.statusCode = 409;
          } else {
            files[request.uri.pathSegments.last] =
                await utf8.decoder.bind(request).join();
            response.statusCode = 201;
          }
        } else if (request.method == 'GET') {
          final data = files[request.uri.pathSegments.last];
          response.statusCode = data == null ? 404 : 200;
          if (data != null) {
            response.headers.contentType = ContentType.json;
            response.add(utf8.encode(data));
          }
        } else {
          response.statusCode = 405;
        }
        await response.close();
      }
    }();
    store = WebdavBackupStore(
        '  http://${server.address.address}:${server.port}/dav/talk  ',
        ' test-user ',
        'test-password');
  });

  tearDown(() async {
    store.close();
    await server.close(force: true);
    await serving;
  });

  test('test checks the configured directory instead of trusting OPTIONS',
      () async {
    baseExists = false;
    await expectLater(store.testConnection(), throwsA(isA<DioException>()));
    expect(requests, everyElement(startsWith('PROPFIND /dav/talk/')));
  });

  test('missing configured directory is not mistaken for an empty backup list',
      () async {
    baseExists = false;
    await expectLater(store.listBackups(), throwsA(isA<DioException>()));
    expect(requests.any((r) => r.contains('/moetalk/')), isFalse);
  });

  test('first refresh returns an empty list without modifying the server',
      () async {
    expect(await store.listBackups(), isEmpty);
    expect(backupsExist, isFalse);
    expect(requests, everyElement(startsWith('PROPFIND ')));
  });

  test('authentication failure is reported without leaking credentials',
      () async {
    denyAuthentication = true;
    try {
      await store.testConnection();
      fail('Expected authentication failure');
    } on DioException catch (error) {
      final message = webdavErrorMessage(error);
      expect(message, contains('Authentication failed'));
      expect(message, isNot(contains('test-password')));
      expect(message, isNot(contains('test-user')));
    }
  });

  test('creates backup folder and round-trips a full UTF-8 configuration',
      () async {
    const name = '备份 #1.json';
    final content = jsonEncode({
      'name': '美园',
      'enabled': true,
      'count': 3,
      'items': ['one', 'two'],
      'temp_history': '[]'
    });
    await store.write(name, content);
    expect(backupsExist, isTrue);
    expect(files[name], content);
    expect(await store.read(name), content);
    expect((await store.listBackups()).map((file) => file.name), [name]);
    expect(requests.any((r) => r.startsWith('MKCOL ')), isTrue);
  });

  test('lists named backups as well as timestamp backups', () async {
    backupsExist = true;
    files.addAll(
        {'1779000000000.json': '{}', 'MoeBackup.JSON': '{}', 'notes.txt': ''});
    expect((await store.listBackups()).map((file) => file.name),
        ['MoeBackup.JSON', '1779000000000.json']);
  });

  test('invalid URLs and filenames fail before sending requests', () async {
    expect(() => WebdavBackupStore('not-a-url', '', ''), throwsFormatException);
    await expectLater(
        store.write('../other.json', '{}'), throwsFormatException);
    expect(requests, isEmpty);
  });
}
