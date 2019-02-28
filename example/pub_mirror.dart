import 'package:pub_mirror/pub_mirror.dart' as pub_mirror;

main() async {
  final tool = pub_mirror.PubMirrorTool('/tmp/pub/', 'http://example.com/pub/',
      upstream: 'https://pub.dartlang.org/api',
      verbose: true,
      maxConnections: 10);

  // iterate over all the packages
  //await for (var package in tool.listAllPackages()) {
    //print('-> ${package.name}');
  //}

  // download the single package
  await tool.downloadPackage('pub_mirror');

  // download all packages with 100 threads
  await tool.download(100, overwrite: false);
}
