import "dart:io" as io;
import "package:http/http.dart" as http;
import "package:pub_client/pub_client.dart";

import "./http.dart";
import "./json.dart";

class PubMirrorTool {
  final String upstream, destination, serving_url;
  final _http_client = io.HttpClient();
  PubClient _pub_client;

  PubMirrorTool(this.upstream, this.destination, this.serving_url) {
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
    var full_package = await _pub_client.getPackage(name);
    // TODO: call
    await savePackageInfo(full_package, '');
    for (var version in full_package.versions) {
      print(
          '--> Downloading ${name}@${version.version} from ${version.archive_url}');
      await saveVersionInfo(version, '');
      await saveArchiveFile(version.archive_url, '/dev/null');
    }
  }

  Future savePackageInfo(FullPackage pkg, String path) async {
    // TODO: meet the requirements at
    // https://github.com/dart-lang/pub_server/blob/master/lib/shelf_pubserver.dart#L30-L49
    //print('${pkg.url} ==> ${json.encode(SerializeToJson(pkg))}');
  }

  Future saveVersionInfo(Version ver, String path) async {
    // TODO: meet the requirements at
    // https://github.com/dart-lang/pub_server/blob/master/lib/shelf_pubserver.dart#L53-L65
    //print('${ver.url} ==> ${json.encode(SerializeToJson(ver))}');
  }

  Future saveArchiveFile(String url, String path) async {
    // TODO: meet the requirements at
    // https://github.com/dart-lang/pub_server/blob/master/lib/shelf_pubserver.dart#L69-L75
    await saveFileTo(url, path);
  }

  Future download() async {
    await for (var package in listAllPackages()) {
      print('Downloading ${package.name}');
      await downloadPackage(package.name);
    }
  }
}
