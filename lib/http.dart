import 'dart:io' as io;
import 'dart:math' as math;

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
  var request = await client.getUrl(Uri.parse(url));
  var response = await request.close();
  if (response.statusCode >= 400) {
    await response.drain();
    throw StatusCodeException(
      reason: response.reasonPhrase,
      url: url,
      statusCode: response.statusCode,
    );
  }

  final io_sink = io.File(destination).openWrite();
  final watch = Stopwatch()..start();
  var downloaded_length = 0;
  final progress_printer = Stream.periodic(Duration(seconds: 1)).listen((_) {
    final seconds = watch.elapsed.inSeconds;
    logger.info('[${url} ===> ${destination}] ${(100 * downloaded_length / response.contentLength).toStringAsFixed(2)}% Total: ${getSize(response.contentLength)} Downloaded: ${getSize(downloaded_length)} Speed: ${getSize(downloaded_length/seconds)}/s');
  });
  try {
    await for (var block in response) {
      io_sink.add(block);
      downloaded_length += block.length;
    }
  } finally {
    await io_sink.close();
    await progress_printer.cancel();
  }
}
