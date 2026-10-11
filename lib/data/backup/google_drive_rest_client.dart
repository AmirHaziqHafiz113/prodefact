import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/inspection/backup/drive_backup.dart';

/// [GoogleDriveClient] over the Drive v3 REST API. Only ever touches
/// files this app created (`drive.file` scope). Uploads use the
/// resumable protocol (photos can exceed the 5 MB multipart limit).
/// Folders and files carry stable ProDefact ids in `appProperties`, so
/// lookups never depend on human-readable names and a retried upload is
/// found instead of duplicated.
class GoogleDriveRestClient implements GoogleDriveClient {
  GoogleDriveRestClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _fileFields = 'id,size,md5Checksum,trashed';
  static const _timeout = Duration(seconds: 60);

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      if (response.statusCode == 401) {
        throw const DriveAuthRequiredException();
      }
      if (response.statusCode >= 400) {
        throw DriveApiException(response.statusCode);
      }
      return response;
    } on SocketException {
      throw const DriveNetworkException();
    } on TimeoutException {
      throw const DriveNetworkException();
    } on http.ClientException {
      throw const DriveNetworkException();
    }
  }

  /// `appProperties has { key='k' and value='v' }` with quotes escaped.
  static String _appPropertyQuery(String key, String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    return "appProperties has { key='$key' and value='$escaped' } "
        'and trashed=false';
  }

  Future<Map<String, dynamic>?> _findOne(String token, String query) async {
    final uri = Uri.parse(_api).replace(
      queryParameters: {
        'q': query,
        'fields': 'files($_fileFields)',
        'pageSize': '1',
        'spaces': 'drive',
      },
    );
    final response = await _send(() => _http.get(uri, headers: _auth(token)));
    final files = (jsonDecode(response.body) as Map<String, dynamic>)['files'];
    if (files is List && files.isNotEmpty) {
      return files.first as Map<String, dynamic>;
    }
    return null;
  }

  static DriveFileInfo _info(Map<String, dynamic> json) => DriveFileInfo(
    id: json['id'] as String,
    size: int.tryParse('${json['size'] ?? ''}'),
    md5Checksum: json['md5Checksum'] as String?,
  );

  @override
  Future<String> ensureFolder({
    required String accessToken,
    required String name,
    required String folderKey,
    String? parentId,
  }) async {
    final existing = await _findOne(
      accessToken,
      "${_appPropertyQuery('prodefactFolderKey', folderKey)} and "
      "mimeType='application/vnd.google-apps.folder'",
    );
    if (existing != null) return existing['id'] as String;
    final response = await _send(
      () => _http.post(
        Uri.parse('$_api?fields=id'),
        headers: {
          ..._auth(accessToken),
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'mimeType': 'application/vnd.google-apps.folder',
          'parents': ?(parentId == null ? null : [parentId]),
          'appProperties': {'prodefactFolderKey': folderKey},
        }),
      ),
    );
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  @override
  Future<DriveFileInfo?> findByEvidenceId({
    required String accessToken,
    required String evidenceId,
  }) async {
    final found = await _findOne(
      accessToken,
      _appPropertyQuery('prodefactEvidenceId', evidenceId),
    );
    return found == null ? null : _info(found);
  }

  @override
  Future<DriveFileInfo> upload({
    required String accessToken,
    required String folderId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    required Map<String, String> appProperties,
  }) async {
    // 1. Start a resumable session with the metadata.
    final start = await _send(
      () => _http.post(
        Uri.parse('$_upload?uploadType=resumable&fields=$_fileFields'),
        headers: {
          ..._auth(accessToken),
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': mimeType,
          'X-Upload-Content-Length': '${bytes.length}',
        },
        body: jsonEncode({
          'name': fileName,
          'parents': [folderId],
          'appProperties': appProperties,
        }),
      ),
    );
    final location = start.headers['location'];
    if (location == null) throw const DriveApiException(502);
    // 2. Send the bytes to the session URL.
    final response = await _send(
      () => _http.put(
        Uri.parse(location),
        headers: {
          ..._auth(accessToken),
          'Content-Type': mimeType,
          'Content-Length': '${bytes.length}',
        },
        body: bytes,
      ),
    );
    return _info(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<DriveFileInfo?> getFile({
    required String accessToken,
    required String fileId,
  }) async {
    try {
      final response = await _send(
        () => _http.get(
          Uri.parse('$_api/$fileId?fields=$_fileFields'),
          headers: _auth(accessToken),
        ),
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['trashed'] == true) return null;
      return _info(json);
    } on DriveApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<int>> download({
    required String accessToken,
    required String fileId,
  }) async {
    final response = await _send(
      () => _http.get(
        Uri.parse('$_api/$fileId?alt=media'),
        headers: _auth(accessToken),
      ),
    );
    return response.bodyBytes;
  }
}
