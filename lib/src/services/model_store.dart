import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Content-addressed files and atomic pointer replacement keep the last model usable.
class ModelStore {
  ModelStore(this.directory);
  final Directory directory;
  bool _installing = false;
  Future<String?> activePath({String? expectedHash}) async {
    final pointer = File(p.join(directory.path, 'active.json'));
    if (!await pointer.exists()) return null;
    final j = jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
    final hash = j['sha256'] as String?;
    if (hash == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) return null;
    if (expectedHash != null && hash != expectedHash.toLowerCase()) return null;
    final file = File(p.join(directory.path, '$hash.gguf'));
    if (!await file.exists()) return null;
    if ((await sha256.bind(file.openRead()).first).toString() != hash) {
      return null;
    }
    return file.path;
  }

  Future<String> importFile(File source, String expectedHash) =>
      install(source.openRead(), expectedHash);
  Future<String> download(Uri uri, String expectedHash) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('HTTPS model URL required.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
            'Model server returned ${response.statusCode}. Use a direct HTTPS download URL.');
      }
      return await install(
          response.timeout(const Duration(seconds: 60)), expectedHash);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> install(Stream<List<int>> bytes, String expectedHash) async {
    if (_installing) throw StateError('An installation is already running.');
    final hash = expectedHash.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Enter the expected 64-character SHA-256.');
    }
    _installing = true;
    final part = File(p.join(directory.path, '${const Uuid().v4()}.part'));
    try {
      await directory.create(recursive: true);
      final sink = part.openWrite();
      try {
        await sink.addStream(bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      if ((await sha256.bind(part.openRead()).first).toString() != hash) {
        throw const FormatException(
            'SHA-256 mismatch. Previous model retained.');
      }
      final handle = await part.open();
      List<int> magic;
      try {
        magic = await handle.read(4);
      } finally {
        await handle.close();
      }
      if (ascii.decode(magic, allowInvalid: true) != 'GGUF') {
        throw const FormatException('Not a GGUF model.');
      }
      final target = p.join(directory.path, '$hash.gguf');
      await part.rename(target);
      final pointer = File(p.join(directory.path, 'active.json.tmp'));
      await pointer.writeAsString(jsonEncode({'sha256': hash}), flush: true);
      await pointer.rename(p.join(directory.path, 'active.json'));
      return target;
    } finally {
      if (await part.exists()) await part.delete();
      _installing = false;
    }
  }
}
