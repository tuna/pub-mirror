Pub Mirror
==========

[![Pub Package](https://img.shields.io/pub/v/pub_mirror.svg)](https://pub.dartlang.org/packages/pub_mirror)

A multi-thread tool to download content from [Pub](http://pub.dartlang.org).
Then the result can be served by a http server and taken as the backend of
[pub](https://github.com/dart-lang/pub), [flutter](https://github.com/flutter/flutter)
or even Pub Mirror itself.

With this tool, you can build a local mirror of pub with no need of unstable
reverse proxy or dynamic server like [pub_server](https://github.com/dart-lang/pub_server).

Installation
------------

It can be installed from pub by:

```bash
$ pub global activate pub_mirror
```

or installed from source directly by:

```bash
$ cd path/to/pub-mirror
$ pub get
# then it can be run by following command
$ dart bin/dart_mirror.dart
```

Using the tool
--------------

```bash
$ pub_mirror --help
Usage:
pub_mirror [options] <dest-path> <serving-url>

Example: pub_mirror /tmp/pub/ file:///tmp/pub/

Options:
-h, --help              print usage and exit
-v, --verbose           more verbose output
-o, --[no-]overwrite    overwrite existing meta files
-u, --upstream          the upstream to mirror from
                        (defaults to "https://pub.dartlang.org/api")

-c, --connections       max number of connections
                        (defaults to "10")

-p, --concurrency       max number of packages to download in parallel
                        (defaults to "1")
```

The `dest-path` is where you would like to save the packages and `serving-url`
is the base url that you would like to serving on.

**file:///tmp/pub/ is just used as an example, the file scheme is not supported by pub.**

The packages are downloaded incrementally, which means:
1. If the process is interrupted and resumed, packages and versions has been downloaded will be skipped.
2. If the process is completed and restarted again, only new packages and new releases will be downloaded.

Service
-------

In order to make the mirror accessible by the client, we must serve it with a web server.

An example for nginx is:

```nginx
http {
  server {
    listen 80;  # identical to the scheme port in the serving-url
    listen ssl 443;  # if the scheme in the serving-url is https
    server_name example.com;  # identical to the hostname in the serving-url

    location /pub/ {  # identical to the path in the serving-url
      root path/to/path;  # identical to the dest-path
      location /pub/api/ {
        try_files $uri $uri/meta.json =404;  # information of packages and versions are saved in meta.json
      }
    }
  }
}
```

Start the nginx and enjoy the speed!

Test
----

To test the configuration of the web server, You can visit following URLs:
1. http://example.com/pub/api/packages  # a large json file
2. http://example.com/pub/api/packages/pub_mirror  # a json file
3. http://example.com/pub/api/packages/pub_mirror/versions/0.1.0  # a json file
3. http://example.com/pub/packages/pub_mirror/versions/0.1.0.tar.gz  # an archive file

Using the mirror
----------------

Setting the environment `PUB_HOSTED_URL` to the `serving-url`, then both `pub`
and `flutter` will download packages from your mirror.

```bash
$ export PUB_HOSTED_URL="http://example.com/pub/"
$ pub get  # downloaded from http://example.com/pub/
$ flutter packages get  # downloaded from http://example.com/pub/
```

Use case
--------

[Dart repo](https://mirrors.tuna.tsinghua.edu.cn/help/dart-pub/) of TUNA mirrors is served by this tool.
