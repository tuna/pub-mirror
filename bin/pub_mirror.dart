import 'dart:io';
import 'package:pub_mirror/logging.dart';
import 'package:pub_mirror/pub_mirror.dart' as pub_mirror;
import 'package:args/args.dart';

ArgResults parseArgs(List<String> arguments) {
  var parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'print usage and exit')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'more verbose output')
    ..addFlag('overwrite', abbr: 'o', help: 'overwrite existing meta files')
    ..addOption('upstream',
        abbr: 'u',
        help: 'the upstream to mirror from',
        defaultsTo: 'https://pub.dartlang.org/api')
    ..addOption('connections',
        abbr: 'c', help: 'max number of connections', defaultsTo: '10')
    ..addOption('concurrency',
        abbr: 'p',
        help: 'max number of packages to download in parallel',
        defaultsTo: '1');
  var result = parser.parse(arguments);
  if (result['help'] ||
      int.tryParse(result['concurrency']) == null ||
      int.tryParse(result['connections']) == null ||
      result.rest.length != 2) {
    print("""Usage:
pub_mirror [options] <dest-path> <serving-url>

Example: pub_mirror /tmp/pub/ file:///tmp/pub/

Options:
${parser.usage}""");
    exit(0);
  }
  return result;
}

main(List<String> arguments) async {
  var args = parseArgs(arguments);
  initializeLogger(verbose: args['verbose']);
  await pub_mirror.PubMirrorTool(args.rest[0], args.rest[1],
          upstream: args['upstream'],
          verbose: args['verbose'],
          maxConnections: int.parse(args['connections']))
      .download(int.parse(args['concurrency']), overwrite: args['overwrite']);
  exit(0);
}
