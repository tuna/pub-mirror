FROM google/dart:2.1.1

RUN pub global activate pub_mirror 1.0.1

ENTRYPOINT ["/root/.pub-cache/bin/pub_mirror"]
