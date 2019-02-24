import "dart:io" as io;
import "dart:convert" as convert;
import "package:http/http.dart" as http;
import "package:path/path.dart" as path;
import "package:pub_client/pub_client.dart";

import "./http.dart";
import "./json.dart";

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
      {this.verbose = true}) {
    _pub_client = PubClient(
        client: http.IOClient(_http_client), baseApiUrl: this.upstream);
  }

  Stream<Package> listAllPackages() async* {
    for (var i = 1;; i++) {
      Page package_page = await _pub_client.getPageOfPackages(i);
      for (var package in package_page.packages) {
        yield package;
      }
      if (package_page.next_url == null || package_page.next_url.trim() == "") {
        break;
      }
    }
  }

  Future downloadPackage(String name) async {
    final full_package = await _pub_client.getPackage(name);
    // TODO: call
    for (var version in full_package.versions) {
      if (verbose) {
        print('--> Downloading ${name}@${version.version}');
      }
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
      await saveVersionInfo(
          version,
          path.join(api_path, 'packages', name, 'versions', version.version,
              meta_filename));
    }
    await savePackageInfo(
        full_package, path.join(api_path, 'packages', name, meta_filename));
  }

  Future savePackageInfo(FullPackage pkg, String destination) async {
    if (verbose) {
      print('==> saving ${destination}');
    }
    await ensureDirectoryCreated(destination);
    final content = convert.json.encode(SerializeToJson(pkg));
    await io.File(destination).writeAsString(content);
  }

  Future saveVersionInfo(Version ver, String destination) async {
    if (verbose) {
      print('==> saving ${destination}');
    }
    await ensureDirectoryCreated(destination);
    final content = convert.json.encode(SerializeToJson(ver));
    await io.File(destination).writeAsString(content);
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

  Future download() async {
    await for (var package in listAllPackages()) {
      print('Downloading ${package.name}');
      await downloadPackage(package.name);
    }
  }
}
