import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:async' as async;
import 'package:retry/retry.dart' as retry;

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
  client ??= io.HttpClient();

  io.HttpClientResponse response = await retry.RetryOptions(maxAttempts: 3).retry(() async {
    logger.fine("Connecting to ${url}");
    final request = await client.getUrl(Uri.parse(url)).timeout(Duration(seconds: 10));
    logger.fine("Connection established: ${url} (${request.connectionInfo.remoteAddress})");
    return await request.close().timeout(Duration(seconds: 10));
  }, retryIf: (e) => e is async.TimeoutException);
  logger.fine("Response received: ${url}");

  if (response.statusCode >= 400) {
    logger.fine("Non-2xx status code: ${url}");
    await response.drain();
    throw StatusCodeException(
      reason: response.reasonPhrase,
      url: url,
      statusCode: response.statusCode,
    );
  }

  // save response to buffer
  final watch = Stopwatch()..start();
  final List<int> buffer = [];
  final progress_printer = Stream.periodic(Duration(seconds: 1)).listen((_) {
    final seconds = watch.elapsed.inSeconds;
    final downloaded_length = buffer.length;
    logger.info('[${url} ===> ${destination}] ${(100 * downloaded_length / response.contentLength).toStringAsFixed(2)}% Total: ${getSize(response.contentLength)} Downloaded: ${getSize(downloaded_length)} Speed: ${getSize(downloaded_length/seconds)}/s');
  });
  try {
    await for(var chunk in response.timeout(Duration(seconds: 10))) {
      buffer.addAll(chunk);
    }
  } catch (e) {
    print('Unhandled exception during downloading: $e');
    rethrow;
  } finally {
    await progress_printer.cancel();
  }
  assert(buffer.length == response.contentLength);

  // save content in buffer to file
  final io_sink = io.File(destination).openWrite();
  io_sink.add(buffer);
  await io_sink.close();

  logger.info('[${url} ===> ${destination}] ${getSize(response.contentLength)}(${getSize(response.contentLength*1000/watch.elapsed.inMilliseconds)}/s) saved.');
}
