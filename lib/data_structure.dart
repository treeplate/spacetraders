// modified from https://github.com/treeplate/isd_treeclient/blob/master/lib/data-structure.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show ChangeNotifier, Offset;

import 'api.dart';
import 'platform_specific.dart';

const String kGalaxyCookieName = 'galaxy';
const String kSystemSymbolsCookieName = 'system-symbols';

final int integerLimit32 = 0xFFFFFFFF;

extension type StarIdentifier._((int category, int subindex) _value) {
  int get category => _value.$1;
  int get subindex => _value.$2;
  int get value => (_value.$1 << 20) + _value.$2;
  String get displayName => 'S${value.toRadixString(16).padLeft(6, '0')}';
  factory StarIdentifier.parse(int value) {
    return StarIdentifier._((value >> 20, value & 0xFFFFF));
  }
  factory StarIdentifier(int category, int subindex) {
    return StarIdentifier._((category, subindex));
  }
}

// based on data from https://cartography.ancalagon.black/, the furthest star from the center is just over 2^16 pixels from the center in the x direction
const int systemRadius = 70_000;

class DataStructure with ChangeNotifier {
  // x and y are 0..1
  List<List<Offset>>? stars;
  List<List<SystemSymbol>>? starSymbols;
  ServerStatus? serverStatus;

  void downloadGalaxy() async {
    stars = List.generate(10, (i) => []);
    starSymbols = List.generate(10, (i) => []);
    await for (System system in listSystems()) {
      stars![system.type.index].add(
        Offset(
          system.x / (systemRadius * 2) + 1 / 2,
          system.y / (systemRadius * 2) + 1 / 2,
        ),
      );
      starSymbols![system.type.index].add(system.symbol);
      notifyListeners();
    }
    saveGalaxyToFile();
  }

  void saveGalaxyToFile() {
    ByteData data = ByteData(
      4 * (1 + stars!.length + 2 * stars!.fold(0, (a, b) => a + b.length)),
    );
    data.setUint32(0, stars!.length, Endian.host);
    int category = 0;
    int index = stars!.length + 1;
    while (category < stars!.length) {
      data.setUint32(4 * (category + 1), stars![category].length, Endian.host);
      for (Offset star in stars![category]) {
        data.setUint32(
          4 * index,
          (star.dx * integerLimit32).toInt(),
          Endian.host,
        );
        data.setUint32(
          4 * index + 4,
          (star.dy * integerLimit32).toInt(),
          Endian.host,
        );
        index += 2;
      }
      category++;
    }
    saveBinaryBlob(kGalaxyCookieName, data.buffer);
    saveBinaryBlob(
      kSystemSymbolsCookieName,
      utf8.encode(starSymbols!.expand((e) => e).join('\n')).buffer,
    );
  }

  void _parseGalaxyFromFile(ByteBuffer buffer, List<String> symbols) {
    Uint32List rawStars = buffer.asUint32List();
    stars = [];
    starSymbols = [];
    int categoryCount = rawStars[0];
    int category = 0;
    int index = categoryCount + 1;
    assert(
      rawStars.length ==
          categoryCount +
              1 +
              rawStars
                  .sublist(1, categoryCount + 1)
                  .map((e) => e * 2)
                  .reduce((e, f) => e + f),
    );
    int symbolIndex = 0;
    while (category < categoryCount) {
      int categoryLength = rawStars[category + 1];
      int originalIndex = index;
      starSymbols!.add([]);
      stars!.add([]);
      while (index < originalIndex + categoryLength * 2) {
        stars![category].add(
          Offset(
            rawStars[index] / integerLimit32,
            rawStars[index + 1] / integerLimit32,
          ),
        );
        starSymbols![category].add(symbols[symbolIndex]);
        symbolIndex++;
        index += 2;
      }
      category++;
    }
    notifyListeners();
  }

  DataStructure() {
    getServerStatus().then((e) {
      serverStatus = e;
      notifyListeners();
    });
    getBinaryBlob(kGalaxyCookieName).then((rawStars) {
      getBinaryBlob(kSystemSymbolsCookieName).then((rawSystemSymbols) {
        if (rawStars != null && rawSystemSymbols != null) {
          _parseGalaxyFromFile(
            rawStars.buffer,
            utf8.decode(rawSystemSymbols).split('\n'),
          );
        } else {
          downloadGalaxy();
        }
      });
    });
  }
}
