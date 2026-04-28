// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const String kMapTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kMapTileUserAgentPackageName = 'com.helpsignal';

const int _offlineCacheRadiusKm = 100;
const int _offlineCacheMinZoom = 7;
const int _offlineCacheMaxZoom = 12;
const int _offlineCacheSizeBytes = 250 * 1024 * 1024;
const Duration _offlineCacheFreshnessAge = Duration(days: 21);
const Duration _offlineCacheCooldown = Duration(hours: 6);
const double _offlineCacheRefreshDistanceKm = 20;

MapCachingProvider get sharedMapCachingProvider =>
    BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: _offlineCacheSizeBytes,
      overrideFreshAge: _offlineCacheFreshnessAge,
    );

TileProvider createSharedMapTileProvider() => NetworkTileProvider(
  cachingProvider: sharedMapCachingProvider,
  silenceExceptions: true,
);

@immutable
class OfflineMapCacheState {
  const OfflineMapCacheState({
    this.isRunning = false,
    this.statusMessage = '',
    this.completedTiles = 0,
    this.totalTiles = 0,
  });

  final bool isRunning;
  final String statusMessage;
  final int completedTiles;
  final int totalTiles;

  double? get progress =>
      totalTiles == 0 ? null : completedTiles / totalTiles;
}

typedef OfflineMapCacheStateListener = void Function(
  OfflineMapCacheState state,
);

class OfflineMapCacheService {
  OfflineMapCacheService({
    http.Client? httpClient,
    MapCachingProvider? cachingProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _cachingProviderOverride = cachingProvider;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final MapCachingProvider? _cachingProviderOverride;
  final Distance _distance = const Distance();

  OfflineMapCacheState _state = const OfflineMapCacheState();
  OfflineMapCacheStateListener? _listener;
  LatLng? _lastCachedCenter;
  DateTime? _lastCacheCompletedAt;
  bool _isDownloading = false;
  bool _isDisposed = false;

  OfflineMapCacheState get state => _state;
  MapCachingProvider get _cachingProvider =>
      _cachingProviderOverride ?? sharedMapCachingProvider;

  void bind(OfflineMapCacheStateListener listener) {
    _listener = listener;
    listener(_state);
  }

  void unbind(OfflineMapCacheStateListener listener) {
    if (identical(_listener, listener)) {
      _listener = null;
    }
  }

  Future<void> cacheAreaAround(LatLng center) async {
    if (_isDisposed) {
      return;
    }

    if (!_cachingProvider.isSupported) {
      _emit(
        const OfflineMapCacheState(
          statusMessage: 'Offline map cache is not supported here.',
        ),
      );
      return;
    }

    if (_isDownloading) {
      _emit(
        OfflineMapCacheState(
          isRunning: true,
          statusMessage:
              'Offline map download is already running in the background.',
          completedTiles: _state.completedTiles,
          totalTiles: _state.totalTiles,
        ),
      );
      return;
    }

    if (_wasRecentlyCached(center)) {
      _emit(
        const OfflineMapCacheState(
          statusMessage: 'Offline map is already cached near your location.',
        ),
      );
      return;
    }

    final tileUrls = _buildTileUrls(center);
    if (tileUrls.isEmpty) {
      _emit(
        const OfflineMapCacheState(
          statusMessage: 'Unable to prepare offline map tiles for this area.',
        ),
      );
      return;
    }

    final uncachedTileUrls = <String>[];
    for (final tileUrl in tileUrls) {
      final cachedTile = await _cachingProvider.getTile(tileUrl);
      if (cachedTile == null || cachedTile.metadata.isStale) {
        uncachedTileUrls.add(tileUrl);
      }
    }

    if (uncachedTileUrls.isEmpty) {
      _lastCachedCenter = center;
      _lastCacheCompletedAt = DateTime.now();
      _emit(
        const OfflineMapCacheState(
          statusMessage: 'Offline map was already up to date for this area.',
        ),
      );
      return;
    }

    _isDownloading = true;
    var completedTiles = 0;
    var downloadedTiles = 0;
    var encounteredNetworkFailure = false;
    var encounteredProviderLimit = false;

    try {
      for (final tileUrl in uncachedTileUrls) {
        if (_isDisposed) {
          return;
        }

        try {
          final didDownload = await _downloadAndCacheTile(tileUrl);
          if (didDownload) {
            downloadedTiles += 1;
          }
        } on _TileProviderRejectedException {
          encounteredProviderLimit = true;
          break;
        } on Exception {
          encounteredNetworkFailure = true;
          break;
        }

        completedTiles += 1;
        _emitProgress(completedTiles, uncachedTileUrls.length);
      }

      if (encounteredProviderLimit) {
        _emit(
          OfflineMapCacheState(
            statusMessage:
                'The current map server refused bulk offline downloads.',
            completedTiles: completedTiles,
            totalTiles: uncachedTileUrls.length,
          ),
        );
        return;
      }

      if (encounteredNetworkFailure) {
        final message = downloadedTiles == 0
            ? 'Internet is unavailable for offline map download right now.'
            : 'Offline map was partially updated and will continue later.';
        _emit(
          OfflineMapCacheState(
            statusMessage: message,
            completedTiles: completedTiles,
            totalTiles: uncachedTileUrls.length,
          ),
        );
        return;
      }

      _lastCachedCenter = center;
      _lastCacheCompletedAt = DateTime.now();
      _emit(
        OfflineMapCacheState(
          statusMessage: downloadedTiles == 0
              ? 'Offline map was already up to date for this area.'
              : 'Offline map updated for $_offlineCacheRadiusKm km around you.',
          completedTiles: uncachedTileUrls.length,
          totalTiles: uncachedTileUrls.length,
        ),
      );
    } finally {
      _isDownloading = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _listener = null;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<bool> _downloadAndCacheTile(String url) async {
    final response = await _httpClient
        .get(
          Uri.parse(url),
          headers: const {
            'User-Agent':
                '$kMapTileUserAgentPackageName offline-map-cache prototype',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const _TileProviderRejectedException();
    }

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Tile download failed with status ${response.statusCode}',
        Uri.parse(url),
      );
    }

    final metadata = _metadataFromHeaders(response.headers);
    await _cachingProvider.putTile(
      url: url,
      metadata: metadata,
      bytes: response.bodyBytes,
    );
    return true;
  }

  CachedMapTileMetadata _metadataFromHeaders(Map<String, String> headers) {
    try {
      return CachedMapTileMetadata.fromHttpHeaders(
        headers,
        fallbackFreshnessAge: _offlineCacheFreshnessAge,
      );
    } catch (_) {
      return CachedMapTileMetadata(
        staleAt: DateTime.now().add(_offlineCacheFreshnessAge),
        lastModified: null,
        etag: null,
      );
    }
  }

  void _emitProgress(int completedTiles, int totalTiles) {
    if (completedTiles <= 0) {
      return;
    }

    if (completedTiles != 1 &&
        completedTiles != totalTiles &&
        completedTiles % 25 != 0) {
      return;
    }

    _emit(
      OfflineMapCacheState(
        isRunning: completedTiles < totalTiles,
        statusMessage:
            'Downloading offline map for $_offlineCacheRadiusKm km around you.',
        completedTiles: completedTiles,
        totalTiles: totalTiles,
      ),
    );
  }

  bool _wasRecentlyCached(LatLng center) {
    final lastCenter = _lastCachedCenter;
    final lastCompletedAt = _lastCacheCompletedAt;
    if (lastCenter == null || lastCompletedAt == null) {
      return false;
    }

    final isStillFresh =
        DateTime.now().difference(lastCompletedAt) < _offlineCacheCooldown;
    if (!isStillFresh) {
      return false;
    }

    final movedDistance = _distance.as(
      LengthUnit.Kilometer,
      lastCenter,
      center,
    );
    return movedDistance < _offlineCacheRefreshDistanceKm;
  }

  List<String> _buildTileUrls(LatLng center) {
    final latDelta = _offlineCacheRadiusKm / 111.32;
    final lonScale = max(cos(center.latitudeInRad).abs(), 0.2);
    final lonDelta = _offlineCacheRadiusKm / (111.32 * lonScale);
    final north = _clampLatitude(center.latitude + latDelta);
    final south = _clampLatitude(center.latitude - latDelta);
    final west = _normalizeLongitude(center.longitude - lonDelta);
    final east = _normalizeLongitude(center.longitude + lonDelta);
    final tiles = <String>[];

    for (var zoom = _offlineCacheMinZoom; zoom <= _offlineCacheMaxZoom; zoom++) {
      final minY = _latToTileY(north, zoom);
      final maxY = _latToTileY(south, zoom);
      final xIndices = _tileXRange(west, east, zoom);

      for (final x in xIndices) {
        for (var y = minY; y <= maxY; y++) {
          tiles.add(_tileUrlFor(x, y, zoom));
        }
      }
    }

    return tiles;
  }

  List<int> _tileXRange(double west, double east, int zoom) {
    final maxIndex = (1 << zoom) - 1;
    final minX = _lonToTileX(west, zoom);
    final maxX = _lonToTileX(east, zoom);

    if (west <= east) {
      return [for (var x = minX; x <= maxX; x++) x];
    }

    return [
      for (var x = minX; x <= maxIndex; x++) x,
      for (var x = 0; x <= maxX; x++) x,
    ];
  }

  int _lonToTileX(double lon, int zoom) {
    final tileCount = 1 << zoom;
    final normalized = ((lon + 180) / 360 * tileCount).floor();
    return normalized.clamp(0, tileCount - 1);
  }

  int _latToTileY(double lat, int zoom) {
    final tileCount = 1 << zoom;
    final latRad = lat * pi / 180;
    final mercator = log(tan(latRad) + 1 / cos(latRad));
    final normalized = ((1 - mercator / pi) / 2 * tileCount).floor();
    return normalized.clamp(0, tileCount - 1);
  }

  double _clampLatitude(double latitude) =>
      (latitude.clamp(-85.0511, 85.0511) as num).toDouble();

  double _normalizeLongitude(double longitude) {
    var normalized = longitude;
    while (normalized < -180) {
      normalized += 360;
    }
    while (normalized > 180) {
      normalized -= 360;
    }
    return normalized;
  }

  String _tileUrlFor(int x, int y, int zoom) {
    return kMapTileUrlTemplate
        .replaceAll('{z}', '$zoom')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }

  void _emit(OfflineMapCacheState state) {
    _state = state;
    _listener?.call(state);
  }
}

class _TileProviderRejectedException implements Exception {
  const _TileProviderRejectedException();
}
