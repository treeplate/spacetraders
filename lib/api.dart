import 'dart:convert';

import 'package:http/http.dart';

final Uri baseURI = Uri(
  scheme: 'https',
  host: 'api.spacetraders.io',
  port: 80,
  path: '/v2',
);

enum RateLimitType(final String name) {
  account("Account"),
  ipAddress("IP Address")
}

Future<void> parseAndThrowError(Response response, String path) async {
  Map<String, Object> rawError =
      (json.decode(response.body) as Map<String, dynamic>).cast();
  if (rawError['error'] is String) {
    // HTTP-level error (e.g. 404)
    String message = rawError.remove('message') as String;
    String error = rawError.remove('error') as String;
    int statusCode = rawError.remove('statusCode') as int;
    assert(statusCode == response.statusCode, 'statusCode != http status code');
    String statusCodeMessage =
        (await _getErrorCodes())[statusCode] ?? 'status code not documented';
    assert(rawError.isEmpty, 'unexpected fields in error: $rawError');
    throw FormatException(
      'Error response to GET:$path, code ${response.statusCode}Status code message: $statusCodeMessage\nError: $error\nMessage: $message',
    );
  } else {
    // Error of the form documented by https://spacetraders.io/api-guide/response-errors (e.g. missing token)
    Map<String, Object> rawInnerError =
        (rawError.remove('error') as Map<String, dynamic>).cast();
    String message = rawInnerError.remove('message') as String;
    int statusCode = rawInnerError.remove('code') as int;
    Map<String, Object>? data =
        (rawInnerError.remove('data') as Map<String, dynamic>?)?.cast();
    String statusCodeMessage =
        (await _getErrorCodes())[statusCode] ?? 'status code not documented';
    String? requestID = rawInnerError.remove('requestId') as String?;
    assert(
      rawInnerError.isEmpty,
      'unexpected fields in inner error: $rawInnerError',
    );
    assert(rawError.isEmpty, 'unexpected fields in error: $rawError');
    if (statusCode == 429) {
      String typeName = data!.remove('type') as String;
      double retryAfter = data.remove('retryAfter') as double;
      int limitBurst = data.remove('limitBurst') as int;
      assert(limitBurst == 30);
      int limitPerSecond = data.remove('limitPerSecond') as int;
      assert(limitPerSecond == 2);
      int remaining = data.remove('remaining') as int;
      assert(remaining == 0);
      DateTime reset = DateTime.parse(data.remove('reset') as String);
      RateLimitType type = RateLimitType.values.singleWhere(
        (e) => e.name == typeName,
      );
      print(
        'rate limit exceeded, waiting $retryAfter milliseconds (until $reset)',
      );
      assert(data.isEmpty, 'unexpected fields in rate limit data: $data');
      return Future.pause(Duration(milliseconds: (retryAfter * 1000).toInt()));
    }
    throw FormatException(
      'Error response to GET:$path, code ${response.statusCode}\nStatus code: $statusCode ($statusCodeMessage)\nMessage: $message\nData: $data${requestID == null ? '' : '\nRequest ID: $requestID'}',
    );
  }
}

Future<Map<String, Object>> _get(String path, {String? token}) async {
  Response response = await get(
    baseURI.resolve(path),
    headers: token == null ? null : {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    await parseAndThrowError(response, path);
    return _get(path, token: token);
  }
  return (json.decode(response.body) as Map<String, dynamic>).cast();
}

Future<Map<String, Object>> _post(
  String path, {
  String? token,
  Map<String, Object>? body,
}) async {
  Map<String, String> headers = {};
  if (token != null) headers['Authorization'] = 'Bearer $token';
  if (body != null) headers['Content-Type'] = 'application/json';
  Response response = await post(
    baseURI.resolve(path),
    headers: headers,
    body: json.encode(body),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    await parseAndThrowError(response, path);
    return _post(path, token: token, body: body);
  }
  return (json.decode(response.body) as Map<String, dynamic>).cast();
}

class ServerStats {
  final int agents;
  final int ships;
  final int systems;
  final int waypoints;
  final int accounts;

  new({
    required this.agents,
    required this.ships,
    required this.systems,
    required this.waypoints,
    required this.accounts,
  });
}

typedef AgentSymbol = String;

class Leaderboards {
  final List<({AgentSymbol agentSymbol, int credits})> mostCredits;
  final List<({AgentSymbol agentSymbol, int chartCount})> mostSubmittedCharts;

  new({required this.mostCredits, required this.mostSubmittedCharts});
}

enum Frequency { weekly }

class Announcement {
  final String title;
  final String body;

  new({required this.title, required this.body});
}

class Link {
  final String name;
  final Uri url;

  new({required this.name, required this.url});
}

class ServerStatus {
  final String status;
  final String version;
  final String resetDate;
  final String description;
  final ServerStats stats;
  final DateTime lastMarketUpdate;
  final Leaderboards leaderboards;
  final DateTime nextServerReset;
  final Frequency serverResetFrequency;
  final List<Announcement> announcements;
  // not used in UI
  final List<Link> links;

  new({
    required this.status,
    required this.version,
    required this.resetDate,
    required this.description,
    required this.stats,
    required this.lastMarketUpdate,
    required this.leaderboards,
    required this.nextServerReset,
    required this.serverResetFrequency,
    required this.announcements,
    required this.links,
  });
}

Future<ServerStatus> getServerStatus() async {
  Map<String, Object> rawData = await _get('/');
  Map<String, Object> rawStats =
      (rawData.remove('stats') as Map<String, dynamic>).cast();
  Map<String, Object> rawHealth =
      (rawData.remove('health') as Map<String, dynamic>).cast();
  Map<String, Object> rawServerResets =
      (rawData.remove('serverResets') as Map<String, dynamic>).cast();
  Map<String, Object> rawLeaderboards =
      (rawData.remove('leaderboards') as Map<String, dynamic>).cast();
  String frequencyName = rawServerResets.remove('frequency') as String;
  ServerStatus result = ServerStatus(
    status: rawData.remove('status') as String,
    version: rawData.remove('version') as String,
    resetDate: rawData.remove('resetDate') as String,
    description: rawData.remove('description') as String,
    stats: ServerStats(
      agents: rawStats.remove('agents') as int,
      ships: rawStats.remove('ships') as int,
      systems: rawStats.remove('systems') as int,
      waypoints: rawStats.remove('waypoints') as int,
      accounts: rawStats.remove('accounts') as int,
    ),
    lastMarketUpdate: DateTime.parse(
      rawHealth.remove('lastMarketUpdate') as String,
    ),
    leaderboards: Leaderboards(
      mostCredits: (rawLeaderboards.remove('mostCredits') as List<dynamic>)
          .cast<Object>()
          .map((Object value) {
            Map<String, Object> rawEntry = (value as Map<String, dynamic>)
                .cast();
            ({AgentSymbol agentSymbol, int credits}) result = (
              agentSymbol: rawEntry.remove('agentSymbol') as AgentSymbol,
              credits: rawEntry.remove('credits') as int,
            );
            assert(
              rawEntry.isEmpty,
              'unexpected fields in most credits leaderboard entry: $rawEntry',
            );
            return result;
          })
          .toList(),
      mostSubmittedCharts:
          (rawLeaderboards.remove(
            'mostSubmittedCharts',
          ) as List<dynamic>).cast<Object>().map((Object value) {
            Map<String, Object> rawEntry = (value as Map<String, dynamic>)
                .cast();
            ({AgentSymbol agentSymbol, int chartCount}) result = (
              agentSymbol: rawEntry.remove('agentSymbol') as AgentSymbol,
              chartCount: rawEntry.remove('chartCount') as int,
            );
            assert(
              rawEntry.isEmpty,
              'unexpected fields in most submitted charts leaderboard entry: $rawEntry',
            );
            return result;
          }).toList(),
    ),
    nextServerReset: DateTime.parse(rawServerResets.remove('next') as String),
    serverResetFrequency: Frequency.values.singleWhere(
      (e) => e.name == frequencyName,
    ),
    announcements: (rawData.remove('announcements') as List<dynamic>)
        .cast<Object>()
        .map((Object value) {
          Map<String, Object> rawAnnouncement = (value as Map<String, dynamic>)
              .cast();
          Announcement result = Announcement(
            title: rawAnnouncement.remove('title') as String,
            body: rawAnnouncement.remove('body') as String,
          );
          assert(
            rawAnnouncement.isEmpty,
            'unexpected fields in server announcement: $rawAnnouncement',
          );
          return result;
        })
        .toList(),
    links: (rawData.remove('links') as List<dynamic>).cast<Object>().map((
      Object value,
    ) {
      Map<String, Object> rawLink = (value as Map<String, dynamic>).cast();
      Link result = Link(
        name: rawLink.remove('name') as String,
        url: Uri.parse(rawLink.remove('url') as String),
      );
      assert(rawLink.isEmpty, 'unexpected fields in server link: $rawLink');
      return result;
    }).toList(),
  );
  assert(rawHealth.isEmpty, 'unexpected fields in server health: $rawHealth');
  assert(rawStats.isEmpty, 'unexpected fields in server stats: $rawStats');
  assert(rawData.isEmpty, 'unexpected fields in server status: $rawData');
  return result;
}

Map<int, String>? _errorCodes;

Future<Map<int, String>> _getErrorCodes() async {
  if (_errorCodes != null) return _errorCodes!;
  Map<String, Object> rawData = await _get('/error-codes');
  Map<int, String> result = {};
  List<Object> errorCodes = (rawData.remove('errorCodes') as List<dynamic>)
      .cast();
  for (Object errorCodeObj in errorCodes) {
    Map<String, Object> rawErrorCode = (errorCodeObj as Map<String, dynamic>)
        .cast();
    result[errorCodeObj.remove('code')] = errorCodeObj.remove('name');
    assert(
      rawErrorCode.isEmpty,
      'unexpected fields in error code list: $rawData',
    );
  }
  assert(rawData.isEmpty, 'unexpected fields in error code list: $rawData');
  _errorCodes = result;
  return result;
}

typedef SectorSymbol = String;
typedef SystemSymbol = String;
typedef WaypointSymbol = String;

enum SystemType(final String name) {
  neutronStar('NEUTRON_STAR'),
  redStar('RED_STAR'),
  orangeStar('ORANGE_STAR'),
  blueStar('BLUE_STAR'),
  youngStar('YOUNG_STAR'),
  whiteDwarf('WHITE_DWARF'),
  blackHole('BLACK_HOLE'),
  hypergiant('HYPERGIANT'),
  nebula('NEBULA'),
  unstable('UNSTABLE')
}

enum WaypointType(final String name) {
  planet('PLANET'),
  gasGiant('GAS_GIANT'),
  moon('MOON'),
  orbitalStation('ORBITAL_STATION'),
  jumpGate('JUMP_GATE'),
  asteroidField('ASTEROID_FIELD'),
  asteroid('ASTEROID'),
  engineeredAsteroid('ENGINEERED_ASTEROID'),
  asteroidBase('ASTEROID_BASE'),
  nebula('NEBULA'),
  debrisField('DEBRIS_FIELD'),
  gravityWell('GRAVITY_WELL'),
  artificialGravityWell('ARTIFICIAL_GRAVITY_WELL'),
  fuelStation('FUEL_STATION')
}

class SystemWaypoint {
  final WaypointSymbol symbol;
  final WaypointType type;
  final int x;
  final int y;
  final List<WaypointSymbol> orbitals;
  final WaypointSymbol? orbits;

  new({
    required this.symbol,
    required this.type,
    required this.x,
    required this.y,
    required this.orbitals,
    required this.orbits,
  });
}

enum WaypointTraitSymbol(final String name) {
  uncharted('UNCHARTED'),
  underConstruction('UNDER_CONSTRUCTION'),
  marketplace('MARKETPLACE'),
  shipyard('SHIPYARD'),
  outpost('OUTPOST'),
  scatteredSettlements('SCATTERED_SETTLEMENTS'),
  sprawlingCities('SPRAWLING_CITIES'),
  megaStructures('MEGA_STRUCTURES'),
  pirateBase('PIRATE_BASE'),
  overcrowded('OVERCROWDED'),
  highTech('HIGH_TECH'),
  corrupt('CORRUPT'),
  bureaucratic('BUREAUCRATIC'),
  tradingHub('TRADING_HUB'),
  industrial('INDUSTRIAL'),
  blackMarket('BLACK_MARKET'),
  researchFacility('RESEARCH_FACILITY'),
  millitaryBase('MILITARY_BASE'),
  surveillanceOutpost('SURVEILLANCE_OUTPOST'),
  explorationOutpost('EXPLORATION_OUTPOST'),
  mineralDeposits('MINERAL_DEPOSITS'),
  commonMetalDeposits('COMMON_METAL_DEPOSITS'),
  preciousMetalDeposits('PRECIOUS_METAL_DEPOSITS'),
  rareMetalDeposits('RARE_METAL_DEPOSITS'),
  methanePools('METHANE_POOLS'),
  iceCrystals('ICE_CRYSTALS'),
  explosiveGases('EXPLOSIVE_GASES'),
  strongMagnetosphere('STRONG_MAGNETOSPHERE'),
  vibrantAuroras('VIBRANT_AURORAS'),
  saltFlats('SALT_FLATS'),
  canyons('CANYONS'),
  perpetualDaylight('PERPETUAL_DAYLIGHT'),
  perpetualOvercast('PERPETUAL_OVERCAST'),
  drySeabeds('DRY_SEABEDS'),
  magmaSeas('MAGMA_SEAS'),
  supervolcanoes('SUPERVOLCANOES'),
  ashClouds('ASH_CLOUDS'),
  vastRuins('VAST_RUINS'),
  mutatedFlora('MUTATED_FLORA'),
  terraformed('TERRAFORMED'),
  extremeTemperatures('EXTREME_TEMPERATURES'),
  extremePressure('EXTREME_PRESSURE'),
  diverseLife('DIVERSE_LIFE'),
  scarceLife('SCARCE_LIFE'),
  fossils('FOSSILS'),
  weakGravity('WEAK_GRAVITY'),
  strongGravity('STRONG_GRAVITY'),
  crushingGravity('CRUSHING_GRAVITY'),
  toxicAtmoshpere('TOXIC_ATMOSPHERE'),
  corrosiveAtmoshpere('CORROSIVE_ATMOSPHERE'),
  breathableAtmoshpere('BREATHABLE_ATMOSPHERE'),
  thinAtmoshpere('THIN_ATMOSPHERE'),
  jovian('JOVIAN'),
  rocky('ROCKY'),
  volcanic('VOLCANIC'),
  frozen('FROZEN'),
  swamp('SWAMP'),
  barren('BARREN'),
  temperate('TEMPERATE'),
  jungle('JUNGLE'),
  ocean('OCEAN'),
  radioactive('RADIOACTIVE'),
  microGravityAnomalies('MICRO_GRAVITY_ANOMALIES'),
  debrisCluster('DEBRIS_CLUSTER'),
  deepCraters('DEEP_CRATERS'),
  shallowCraters('SHALLOW_CRATERS'),
  unstableComposition('UNSTABLE_COMPOSITION'),
  hollowedInterior('HOLLOWED_INTERIOR'),
  stripped('STRIPPED')
}

class WaypointTrait {
  final WaypointTraitSymbol symbol;
  final String name;
  final String description;

  new({required this.symbol, required this.name, required this.description});
}

enum WaypointModifierSymbol(final String name) {
  stripped('STRIPPED'),
  unstable('UNSTABLE'),
  radiationLeak('RADIATION_LEAK'),
  criticalLimit('CRITICAL_LIMIT'),
  civilUnrest('CIVIL_UNREST')
}

class WaypointModifier {
  final WaypointModifierSymbol symbol;
  final String name;
  final String description;

  new({required this.symbol, required this.name, required this.description});
}

class Chart {
  final WaypointSymbol waypointSymbol;
  final AgentSymbol submittedBy;
  final DateTime submittedOn;

  new({
    required this.waypointSymbol,
    required this.submittedBy,
    required this.submittedOn,
  });
}

class Waypoint extends SystemWaypoint {
  // all null in the case of this actually being a system waypoint
  final SystemSymbol? systemSymbol;
  final FactionSymbol? faction;

  final List<WaypointTrait>? traits;

  /// actually nullable
  final List<WaypointModifier>? modifiers;

  /// actually nullable
  final Chart? chart;
  final bool? isUnderConstruction;

  new({
    required super.symbol,
    required super.type,
    this.systemSymbol,
    required super.x,
    required super.y,
    required super.orbitals,
    required super.orbits,
    this.faction,
    this.traits,
    this.modifiers,
    this.chart,
    this.isUnderConstruction,
  });
}

enum FactionSymbol(final String name) {
  cosmic('COSMIC'),
  void_('VOID'),
  galactic('GALACTIC'),
  quantum('QUANTUM'),
  dominion('DOMINION'),
  astro('ASTRO'),
  corsairs('CORSAIRS'),
  obsidian('OBSIDIAN'),
  aegis('AEGIS'),
  united('UNITED'),
  solitary('SOLITARY'),
  cobalt('COBALT'),
  omega('OMEGA'),
  echo('ECHO'),
  lords('LORDS'),
  cult('CULT'),
  ancients('ANCIENTS'),
  shadow('SHADOW'),
  ethereal('ETHEREAL'),
}

class System {
  final String constellation;
  final SystemSymbol symbol;
  final SectorSymbol sectorSymbol;
  final SystemType type;
  final int x;
  final int y;
  final List<SystemWaypoint> waypoints;
  final List<FactionSymbol> factions;
  final String name;

  new({
    required this.constellation,
    required this.symbol,
    required this.sectorSymbol,
    required this.type,
    required this.x,
    required this.y,
    required this.waypoints,
    required this.factions,
    required this.name,
  });
}

Waypoint parseWaypoint(Map<String, Object> rawWaypoint, bool fromSystem) {
  Map<String, Object>? rawFaction;
  Map<String, Object>? rawChart;
  if (!fromSystem) {
    rawFaction = (rawWaypoint.remove('faction') as Map<String, dynamic>).cast();
    rawChart = (rawWaypoint.remove('chart') as Map<String, dynamic>?)?.cast();
    assert(
      rawChart == null || rawChart['waypointSymbol'] == rawWaypoint['symbol'],
      'chart symbol incorrect',
    );
  }
  String typeName = rawWaypoint.remove('type') as String;
  String? factionSymbolName = rawFaction?.remove('symbol') as String?;
  Waypoint result = Waypoint(
    symbol: rawWaypoint.remove('symbol') as String,
    type: WaypointType.values.singleWhere((e) => e.name == typeName),
    systemSymbol: fromSystem
        ? null
        : rawWaypoint.remove('systemSymbol') as String,
    x: rawWaypoint.remove('x') as int,
    y: rawWaypoint.remove('y') as int,
    orbitals: (rawWaypoint.remove('orbitals') as List<dynamic>)
        .cast<Object>()
        .map((Object object) {
          Map<String, Object> rawOrbital = (object as Map<String, dynamic>)
              .cast();
          WaypointSymbol result = rawOrbital.remove('symbol') as String;
          assert(
            rawOrbital.isEmpty,
            'unexpected fields in orbital: $rawOrbital',
          );
          return result;
        })
        .toList(),
    orbits: rawWaypoint.remove('orbits') as String?,
    faction: fromSystem
        ? null
        : FactionSymbol.values.singleWhere((e) => e.name == factionSymbolName),

    traits: fromSystem
        ? null
        : (rawWaypoint.remove('traits') as List<dynamic>).cast<Object>().map((
            Object object,
          ) {
            Map<String, Object> rawTrait = (object as Map<String, dynamic>)
                .cast();
            String symbolName = rawTrait.remove('symbol') as String;
            WaypointTrait result = WaypointTrait(
              symbol: WaypointTraitSymbol.values.singleWhere(
                (e) => e.name == symbolName,
              ),
              name: rawTrait.remove('name') as String,
              description: rawTrait.remove('description') as String,
            );
            assert(
              rawTrait.isEmpty,
              'unexpected fields in waypoint trait: $rawTrait',
            );
            return result;
          }).toList(),
    modifiers: fromSystem
        ? null
        : (rawWaypoint.remove('modifiers') as List<dynamic>?)
              ?.cast<Object>()
              .map((Object object) {
                Map<String, Object> rawModifier =
                    (object as Map<String, dynamic>).cast();
                String symbolName = rawModifier.remove('symbol') as String;
                WaypointModifier result = WaypointModifier(
                  symbol: WaypointModifierSymbol.values.singleWhere(
                    (e) => e.name == symbolName,
                  ),
                  name: rawModifier.remove('name') as String,
                  description: rawModifier.remove('description') as String,
                );
                assert(
                  rawModifier.isEmpty,
                  'unexpected fields in waypoint modifier: $rawModifier',
                );
                return result;
              })
              .toList(),
    chart: rawChart == null
        ? null
        : Chart(
            waypointSymbol: rawChart.remove('waypointSymbol') as String,
            submittedBy: rawChart.remove('submittedBy') as String,
            submittedOn: DateTime.parse(
              rawChart.remove('submittedOn') as String,
            ),
          ),
    isUnderConstruction: fromSystem
        ? null
        : rawWaypoint.remove('isUnderConstruction') as bool,
  );
  assert(
    rawFaction?.isEmpty ?? true,
    'unexpected fields in waypoint faction: $rawFaction',
  );
  assert(
    rawChart?.isEmpty ?? true,
    'unexpected fields in waypoint chart: $rawFaction',
  );
  assert(rawWaypoint.isEmpty, 'unexpected fields in waypoint: $rawWaypoint');
  return result;
}

System parseSystem(Map<String, Object> rawSystem) {
  String typeName = rawSystem.remove('type') as String;
  System result = System(
    constellation: rawSystem.remove('constellation') as String,
    symbol: rawSystem.remove('symbol') as String,
    sectorSymbol: rawSystem.remove('sectorSymbol') as String,
    type: SystemType.values.singleWhere((e) => e.name == typeName),
    x: rawSystem.remove('x') as int,
    y: rawSystem.remove('y') as int,
    waypoints: (rawSystem.remove('waypoints') as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((e) => parseWaypoint(e.cast(), true))
        .toList(),
    factions: (rawSystem.remove('factions') as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> rawFaction) {
          String symbolName = rawFaction.remove('symbol');
          FactionSymbol result = FactionSymbol.values.singleWhere(
            (e) => e.name == symbolName,
          );
          assert(
            rawFaction.isEmpty,
            'unexpected fields in faction: $rawFaction',
          );
          return result;
        })
        .toList(),
    name: rawSystem.remove('name') as String,
  );
  assert(rawSystem.isEmpty, 'unexpected fields in system: $rawSystem');
  return result;
}

Future<(List<System>, int)> _listSystems(int page, int limit) async {
  assert(page >= 1);
  assert(limit >= 1);
  assert(limit <= 20);
  Map<String, Object> rawData = await _get('/systems?page=$page&limit=$limit');
  List<System> result = (rawData.remove('data') as List<dynamic>)
      .cast<Object>()
      .map((e) => parseSystem(((e as Map<String, dynamic>).cast())))
      .toList();
  Map<String, Object> rawMeta = (rawData.remove('meta') as Map<String, dynamic>)
      .cast();
  assert(rawMeta.remove('page') == page);
  assert(rawMeta.remove('limit') == limit);
  int total = rawMeta.remove('total') as int;
  assert(rawMeta.isEmpty, 'unexpected fields in meta: $rawMeta');
  assert(rawData.isEmpty, 'unexpected fields in system list: $rawData');
  return (result, total);
}

Stream<System> listSystems() async* {
  var (List<System> page1, int total) = await _listSystems(1, 20);
  yield* Stream.fromIterable(page1);
  int totalPages = (total / 20).ceil();
  int page = 2;
  while (page <= totalPages) {
    yield* Stream.fromFuture(_listSystems(page, 20)).expand((e) {
      assert(e.$2 == total);
      return e.$1;
    });
    page += 1;
  }
}

Future<System> getSystem(SystemSymbol system) async {
  Map<String, Object> rawData = await _get('/systems/$system');
  System result = parseSystem(
    (rawData.remove('data') as Map<Object, dynamic>).cast(),
  );
  assert(rawData.isEmpty, 'unexpected fields in system: $rawData');
  return result;
}