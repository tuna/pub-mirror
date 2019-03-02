import 'package:logging/logging.dart' as logging;
import 'package:quiver_log/log.dart' as quiver_log;

final logger = logging.Logger('pub_mirror');

void initializeLogger({bool verbose = false}) {
  logging.Logger.root.level = verbose ? logging.Level.FINE : logging.Level.INFO;
  final appender = quiver_log.PrintAppender(quiver_log.BASIC_LOG_FORMATTER);
  appender.attachLogger(logger);
}
