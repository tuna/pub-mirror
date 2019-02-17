import "dart:convert";
import "dart:async";
import "package:pub_client/pub_client.dart";

PubClient _client = new PubClient();

Stream<Package> listAllPackages() async* {
  for (var i = 1;; i++) {
    Page package_page = await _client.getPageOfPackages(i);
    for (var package in package_page.packages) {
      yield package;
    }
    if (package_page.next_url == null || package_page.next_url.trim() == "") {
      break;
    }
  }
}

Future downloadPackage(String name) async {
  var full_package = await _client.getPackage(name);
  // TODO: call
  for (var version in full_package.versions) {
    print(
        '--> Downloading ${name}@${version.version} from ${version.archive_url}');
  }
}

Future savePackageInfo(FullPackage pkg, String path) async {
  // TODO: meet the requirements at
  // https://github.com/dart-lang/pub_server/blob/master/lib/shelf_pubserver.dart#L30-L49
}

Future saveVersionInfo(Version ver, String path) async {
  // TODO: meet the requirements at
  // https://github.com/dart-lang/pub_server/blob/master/lib/shelf_pubserver.dart#L53-L65
}

Future saveArchiveFile(String url, String path) async {
  // TODO: meet the requirements at
  // https://github.com/dart-lang/pub_server/blob/master/lib/shelf_pubserver.dart#L69-L75
}

Future downloadAll() async {
  await for (var package in listAllPackages()) {
    print('Downloading ${package.name}');
    await downloadPackage(package.name);
  }
}
