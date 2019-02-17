import 'package:pub_mirror/pub_mirror.dart' as pub_mirror;

main(List<String> arguments) async {
  await pub_mirror.downloadAll();
}
