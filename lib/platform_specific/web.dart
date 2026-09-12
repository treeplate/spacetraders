// modified from https://github.com/treeplate/isd_treeclient/tree/master/lib/platform_specific
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

Map<String, String> cookieCache = {};

Future<String?> getCookie(String name) async {
  String? item = window.localStorage.getItem(name);
  if (item != null) {
    cookieCache[name] = item;
  }
  return item;
}

void setCookie(String name, String? value) {
  if (value == null) {
    window.localStorage.removeItem(name);
    cookieCache.remove(name);
  } else {
    window.localStorage.setItem(name, value);
    cookieCache[name] = value;
  }
}

Future<Uint8List?> getBinaryBlob(String name) async {
  Cache cache = await window.caches.open(name).toDart;
  Response? data = await cache.match('data'.toJS).toDart;
  if (data == null) return null;
  JSArrayBuffer arrayBuffer = await data.arrayBuffer().toDart;
  return arrayBuffer.toDart.asUint8List();
}

Future<void> saveBinaryBlob(String name, ByteBuffer data) async {
  Cache cache = await window.caches.open(name).toDart;
  await cache.put('data'.toJS, Response(data.toJS)).toDart;
}
