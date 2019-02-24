import 'dart:io';
import 'package:pub_mirror/pub_mirror.dart' as pub_mirror;
import 'package:args/args.dart';

ArgResults parseArgs(List<String> arguments) {
  var parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'print usage and exit')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'more verbose output')
    ..addOption('upstream',
        abbr: 'u',
        help: 'set the upstream to mirror from',
        defaultsTo: 'https://pub.dartlang.org/api',
        valueHelp: 'UPSTREAM');
  var result = parser.parse(arguments);
  if (result['help'] || result.rest.length != 2) {
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
  await pub_mirror.PubMirrorTool(args['upstream'], args.rest[0], args.rest[1],
          verbose: args['verbose'])
      .download();
}
