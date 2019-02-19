import "dart:io";
import "dart:convert";
import "dart:mirrors";
import "dart:async";
import "package:pub_client/pub_client.dart";

var _pub_client = PubClient();
var _http_client = HttpClient();

class StatusCodeException implements Exception {
  final String url;
  final int statusCode;
  final String reason;

  StatusCodeException({
    this.url = 'some page',
    this.statusCode = null,
    this.reason = null,
  });

  @override
  String toString() {
    var buffer = StringBuffer('failed');
    if (statusCode != null) {
      buffer.write(' with ${statusCode}');
    }
    buffer.write(' when visiting ${url}');
    if (reason != null) {
      buffer.write(': ${reason}');
    }
    return buffer.toString();
  }
}

dynamic SerializeToJson(dynamic object) {
  var toJsonMethod = reflect(object).type.instanceMembers[Symbol("toJson")];
  if (toJsonMethod != null && toJsonMethod.isRegularMethod) {
    object = object.toJson();
  }

  if (object is List) {
    object = object.map(SerializeToJson).toList();
  }

  if (object is Map) {
    object = Map<String, dynamic>.fromIterable(
        object.entries.where((entry) => entry.value != null),
        key: (entry) => SerializeToJson(entry.key),
        value: (entry) => SerializeToJson(entry.value));
  }

  return object;
}

Future saveFileTo(String url, String path) async {
  var request = await _http_client.getUrl(Uri.parse(url));
  var response = await request.close();
  if (response.statusCode >= 400) {
    await response.drain();
    throw StatusCodeException(
      reason: response.reasonPhrase,
      url: url,
      statusCode: response.statusCode,
    );
  }
  // TODO: progress bar
  response.pipe(File(path).openWrite());
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

Future downloadAll() async {
  await for (var package in listAllPackages()) {
    print('Downloading ${package.name}');
    await downloadPackage(package.name);
  }
}
