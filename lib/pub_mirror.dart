import 'dart:io' as io;
import 'dart:convert' as convert;
import 'dart:async' as async;
import 'package:retry/retry.dart' as retry;
import 'package:path/path.dart' as path;
import 'package:executor/executor.dart' as executor;
import 'package:http/http.dart' as http;
import 'package:pedantic/pedantic.dart' as pedantic;
import 'package:pub_client/pub_client.dart';

import './http.dart';
import './json.dart';
import './logging.dart';

class PubMirrorTool {
  final String upstream, destination, serving_url;
  final verbose;
  final _http_client = io.HttpClient();
  final archive_extension = '.tar.gz';
  final meta_filename = 'meta.json';
  PubClient _pub_client;

  String get api_path => path.join(destination, 'api');
  String get archive_path => destination;
  String get api_url => path.url.join(serving_url, 'api');
  String get archive_url => serving_url;

  /// path to save the meta data of all packages
  String get full_page_path => path.join(api_path, 'packages', meta_filename);

  /// path to save the meta data for the package
  String package_meta_path(String package_name) =>
      path.join(api_path, 'packages', package_name, meta_filename);

  /// path to save the meta data for the version of the package
  String version_meta_path(String package_name, String version) => path.join(
      api_path, 'packages', package_name, 'versions', version, meta_filename);

  /// path to save the archive file for the version of the package
  String version_archive_path(String package_name, String version) => path.join(
      archive_path,
      'packages',
      package_name,
      'versions',
      version + archive_extension);

  /// url to get the meta data for the package
  String package_api_url(String package_name) =>
      path.url.join(api_url, 'packages', package_name);

  /// url to get the meta data for the version of the package
  String version_api_url(String package_name, String version) =>
      path.url.join(api_url, 'packages', package_name, 'versions', version);

  /// url to get the archive file for the version of the package
  String version_archive_url(String package_name, String version) =>
      path.url.join(archive_url, 'packages', package_name, 'versions',
          version + archive_extension);

  PubMirrorTool(this.destination, this.serving_url,
      {this.upstream = 'https://pub.dartlang.org/api',
      this.verbose = true,
      maxConnections = 10}) {
    _http_client.maxConnectionsPerHost = maxConnections;
    _pub_client = PubClient(
        client: http.IOClient(_http_client), baseApiUrl: this.upstream);
  }

  Stream<Package> listAllPackages() async* {
    for (var i = 1;; i++) {
      Page package_page = await retry.RetryOptions(maxAttempts: 3).retry(() async {
        logger.fine('Getting package page $i');
        return await _pub_client.getPageOfPackages(i).timeout(Duration(seconds: 5));
      }, retryIf: (e) => e is async.TimeoutException);
      for (var package in package_page.packages) {
        yield package;
      }
      if (package_page.next_url == null || package_page.next_url.trim() == '') {
        break;
      }
    }
  }

  Future downloadPackage(String name, {bool overwrite = false}) async {
    final full_package = await retry.RetryOptions(maxAttempts: 3).retry(() async {
      logger.fine('Getting details of package $name');
      return await _pub_client.getPackage(name).timeout(Duration(seconds: 5));
    }, retryIf: (e) => e is async.TimeoutException);
    int new_versions_num = 0;
    for (var version in full_package.versions) {
      final current_version_meta_path =
          version_meta_path(name, version.version);
      final version_meta_file = io.File(current_version_meta_path);
      bool new_version = true;
      if (version_meta_file.existsSync() &&
          version_meta_file.statSync().type == io.FileSystemEntityType.file) {
        logger.info('--> Skip ${name}@${version.version}');
        new_version = false;
      } else {
        logger.info('--> Downloading ${name}@${version.version}');
        new_versions_num++;
        final filename = path.basename(version.archive_url);
        assert(filename.endsWith(archive_extension),
            'Unexpected archive filename found: ${filename}');
        await saveArchiveFile(
            version.archive_url, version_archive_path(name, version.version));
      }

      version.archive_url = version_archive_url(name, version.version);
      if (version.version == full_package.latest.version) {
        full_package.latest.archive_url = version.archive_url;
      }
      if (new_version || overwrite) {
        await dumpJsonSafely(version, current_version_meta_path);
      }
    }
    if (new_versions_num > 0 || overwrite) {
      await dumpJsonSafely(full_package, package_meta_path(name));
    }
  }

  Future dumpJsonSafely(dynamic object, String destination) async {
    // Assume that moving file in same directory is atomic
    await ensureDirectoryCreated(destination);
    final dirname = path.dirname(destination);
    final basename = path.basename(destination);
    final tmp_file_path = path.join(dirname, '.${basename}.tmp');
    final content = convert.json.encode(SerializeToJson(object));
    logger.fine('==> saving ${destination}: ${content}');
    final tmp_file =
        await io.File(tmp_file_path).writeAsString(content, flush: true);
    await tmp_file.rename(destination);
  }

  Future saveArchiveFile(String url, String destination) async {
    logger.fine('==> saving ${destination}');
    await ensureDirectoryCreated(destination);
    await saveFileTo(url, destination, client: _http_client);
  }

  Future ensureDirectoryCreated(String file_path) async {
    await io.Directory(path.dirname(file_path)).create(recursive: true);
  }

  void alterPackage(Package pkg) {
    pkg.url = package_api_url(pkg.name);
    pkg.version_url = version_api_url(pkg.name, '{version}');

    pkg.latest.url = version_api_url(pkg.name, pkg.latest.version);
    pkg.latest.archive_url = version_api_url(pkg.name, pkg.latest.version);
    pkg.latest.package_url = pkg.url;

    // no url to manage uploaders or upload new versions
    pkg.uploaders_url = null;
    pkg.new_version_url = null;
  }

  Future download(int concurrency, {bool overwrite = false}) async {
    final exe = executor.Executor(concurrency: concurrency);
    final full_page = Page(packages: <Package>[]);

    final status_printer = Stream.periodic(Duration(seconds: 3)).listen((_) {
      logger.info('Executor: ${exe.runningCount} - ${exe.waitingCount}');
    });

    await for (var package in listAllPackages()) {
      pedantic.unawaited(exe.scheduleTask(() async {
        logger.info('Syncing ${package.name}');
        await downloadPackage(package.name, overwrite: overwrite);
      }));

      pedantic.unawaited(exe.scheduleTask(() async {
        alterPackage(package);
        full_page.packages.add(package);
      }));
    }
    logger.info('All tasks have been scheduled...');
    await exe.join(withWaiting: true);
    logger.info('Stopping the status printer...');
    await status_printer.cancel();
    logger.info('Saving the index...');
    await dumpJsonSafely(full_page, full_page_path);
    logger.info('Done.');
  }
}
