// modified from https://github.com/treeplate/isd_treeclient/tree/master/lib/platform_specific

import 'dart:async';
import 'dart:typed_data';

/// A cache of cookies that have been saved for use synchronously. This is updated by [getCookie] and [setCookie], and possibly other things too.
Map<String, String> cookieCache = {};

/// Gets the cookie associated with [name] from the cookie store and add it to [cookieCache]. This does not mean an actual cookie, but something somehow stored on the local machine.
Future<String?> getCookie(String name) async {
  return cookieCache[name];
}

/// Gets the binary cookie associated with [name] as a Uint8List. This does not mean an actual cookie, but something somehow stored on the local machine. This is a seperate namespace from [getCookie].
Future<Uint8List?> getBinaryBlob(String name) async {
  return null;
}

/// Sets the cookie associated with [name] to [value] and add it to [cookieCache]. This does not mean an actual cookie, but something somehow stored on the local machine.
void setCookie(String name, String? value) {
  if (value == null) {
    cookieCache.remove(name);
  } else {
    cookieCache[name] = value;
  }
}

/// Sets the binary cookie associated with [name] to [data]. This does not mean an actual cookie, but something somehow stored on the local machine. This is a seperate namespace from [setCookie].
Future<void> saveBinaryBlob(String name, ByteBuffer data) async {}
