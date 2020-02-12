import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:async' as async;

import './logging.dart';

class StatusCodeException implements Exception {
  final String url;
  final int statusCode;
  final String reason;

  StatusCodeException({
    this.url = 'some page',
    this.statusCode,
    this.reason,
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

String getSize(num byte) {
  final units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'];
  for (int i = 0; i < units.length; i++) {
    final base = math.pow(1024, i);
    if (byte < base * 1024 || i + 1 == units.length) {
      return '${(byte / base).toStringAsFixed(2)} ${units[i]}';
    }
  }
  return 'NaN';
}

/// download file progressively
Future saveFileTo(String url, String destination, {io.HttpClient client}) async {
  if (client == null) {
    client = io.HttpClient();
  }
  io.HttpClientResponse response;
  for (var retry = 3; retry >= 0; retry--) {
    try {
      logger.fine("Connecting to ${url}");
      var request = await client.getUrl(Uri.parse(url)).timeout(Duration(seconds: 10));
      logger.fine("Connection has been established: ${url}");
      response = await request.close().timeout(Duration(seconds: 10));
      logger.fine("Response has been received: ${url}");
      if (response.statusCode >= 400) {
        logger.fine("Non-2xx status code: ${url}");
        await response.drain();
        throw StatusCodeException(
          reason: response.reasonPhrase,
          url: url,
          statusCode: response.statusCode,
        );
      }
      break;
    } on async.TimeoutException catch (e) {
      if (retry == 0) {
        logger.warning("Failed to connect to ${url}");
        rethrow;
      }
      logger.info("Timeout connecting to ${url}, retrying (${retry})...");
    }
  }

  final watch = Stopwatch()..start();
  List<int> buffer = [];
  var downloaded_length = 0;
  final progress_printer = Stream.periodic(Duration(seconds: 1)).listen((_) {
    final seconds = watch.elapsed.inSeconds;
    logger.info('[${url} ===> ${destination}] ${(100 * downloaded_length / response.contentLength).toStringAsFixed(2)}% Total: ${getSize(response.contentLength)} Downloaded: ${getSize(downloaded_length)} Speed: ${getSize(downloaded_length/seconds)}/s');
  });
  try {
    await for (var block in response.timeout(Duration(seconds: 10))) {
      buffer.addAll(block);
      downloaded_length += block.length;
    }
  } catch (e) {
    print('Unhandled exception during downloading: $e');
    rethrow;
  } finally {
    await progress_printer.cancel();
  }
  assert(downloaded_length == response.contentLength);
  final io_sink = io.File(destination).openWrite();
  io_sink.add(buffer);
  await io_sink.close();
  logger.info('[${url} ===> ${destination}] ${getSize(downloaded_length)} saved.');
}
