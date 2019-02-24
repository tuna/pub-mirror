import 'dart:mirrors' as mirrors;

/// Serialized as json, specialized for object in pub_mirror
dynamic SerializeToJson(dynamic object) {
  var toJsonMethod =
      mirrors.reflect(object).type.instanceMembers[Symbol("toJson")];
  if (toJsonMethod != null && toJsonMethod.isRegularMethod) {
    object = object.toJson();
  }

  if (object is List) {
    object = object.map(SerializeToJson).toList();
  }

  if (object is Map) {
    object = Map<String, dynamic>.fromIterable(
        object.entries.where((entry) => entry.value != null),
        key: (entry) => SerializeToJson(entry.key),
        value: (entry) => SerializeToJson(entry.value));
  }

  return object;
}
