import 'dart:io' as io;
import 'dart:convert' as convert;
import 'package:path/path.dart' as path;
import 'package:executor/executor.dart' as executor;
import 'package:http/http.dart' as http;
import 'package:pedantic/pedantic.dart' as pedantic;
import 'package:pub_client/pub_client.dart';

import './http.dart';
import './json.dart';

class PubMirrorTool {
  final String upstream, destination, serving_url;
  final verbose;
  final _http_client = io.HttpClient();
  final archive_extension = '.tar.gz';
  final meta_filename = 'meta.json';
  PubClient _pub_client;

  String get api_path => path.join(destination, 'api');
  String get archive_path => destination;

  PubMirrorTool(this.upstream, this.destination, this.serving_url,
      {this.verbose = true, maxConnections = 10}) {
    _http_client.maxConnectionsPerHost = maxConnections;
    _pub_client = PubClient(
        client: http.IOClient(_http_client), baseApiUrl: this.upstream);
  }

  Stream<Package> listAllPackages() async* {
    for (var i = 1;; i++) {
      Page package_page = await _pub_client.getPageOfPackages(i);
      for (var package in package_page.packages) {
        yield package;
      }
      if (package_page.next_url == null || package_page.next_url.trim() == '') {
        break;
      }
    }
  }

  Future downloadPackage(String name) async {
    final full_package = await _pub_client.getPackage(name);
    final package_api_path = path.join(api_path, 'packages', name);
    // TODO: call
    for (var version in full_package.versions) {
      final version_api_path =
          path.join(package_api_path, 'versions', version.version);
      final version_meta_path = path.join(version_api_path, meta_filename);
      final version_meta_file = io.File(version_meta_path);
      if (version_meta_file.existsSync() &&
          version_meta_file.statSync().type == io.FileSystemEntityType.file) {
        print('--> Skip ${name}@${version.version}');
        continue;
      }
      print('--> Downloading ${name}@${version.version}');
      final filename = path.basename(version.archive_url);
      assert(filename.endsWith(archive_extension),
          'Unexpected archive filename found: ${filename}');
      await saveArchiveFile(
          version.archive_url,
          path.join(archive_path, 'packages', name, 'versions',
              version.version + archive_extension));
      version.archive_url = path.url.join(serving_url, 'packages', name,
          'versions', version.version + archive_extension);
      if (version.version == full_package.latest.version) {
        full_package.latest.archive_url = version.archive_url;
      }
      await dumpJsonSafely(version, path.join(version_api_path, meta_filename));
    }
    await dumpJsonSafely(
        full_package, path.join(package_api_path, meta_filename));
  }

  Future dumpJsonSafely(dynamic object, String destination) async {
    if (verbose) {
      print('==> saving ${destination}');
    }
    // Assume that moving file in same directory is atomic
    await ensureDirectoryCreated(destination);
    final dirname = path.dirname(destination);
    final basename = path.basename(destination);
    final tmp_file_path = path.join(dirname, '.${basename}.tmp');
    final content = convert.json.encode(SerializeToJson(object));
    final tmp_file =
        await io.File(tmp_file_path).writeAsString(content, flush: true);
    await tmp_file.rename(destination);
  }

  Future saveArchiveFile(String url, String destination) async {
    if (verbose) {
      print('==> saving ${destination}');
    }
    await ensureDirectoryCreated(destination);
    await saveFileTo(url, destination, client: _http_client);
  }

  Future ensureDirectoryCreated(String file_path) async {
    await io.Directory(path.dirname(file_path)).create(recursive: true);
  }

  Future download(int concurrency) async {
    final exe = new executor.Executor(concurrency: concurrency);
    await for (var package in listAllPackages()) {
      pedantic.unawaited(exe.scheduleTask(() async {
        print('Downloading ${package.name}');
        await downloadPackage(package.name);
      }));
    }
    await exe.join();
  }
}
