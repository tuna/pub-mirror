import 'dart:io' as io;

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

/*
 * download file progressively
 */
Future saveFileTo(String url, String path, {io.HttpClient client}) async {
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
  // TODO: progress bar
  response.pipe(io.File(path).openWrite());
}
