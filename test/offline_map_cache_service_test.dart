// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help_signal/services/offline_map_cache_service.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  test('offline failure does not report download progress', () async {
    final service = OfflineMapCacheService(
      httpClient: _ThrowingHttpClient(),
      cachingProvider: _FakeMapCachingProvider(),
    );
    final states = <OfflineMapCacheState>[];

    service.bind(states.add);
    await service.cacheAreaAround(const LatLng(12.9716, 77.5946));

    expect(states.where((state) => state.isRunning), isEmpty);
    expect(
      states.last.statusMessage,
      'Internet is unavailable for offline map download right now.',
    );

    service.dispose();
  });
}

class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw const SocketException('No internet');
  }
}

class _FakeMapCachingProvider implements MapCachingProvider {
  final Map<String, CachedMapTile> _tiles = <String, CachedMapTile>{};

  @override
  bool get isSupported => true;

  @override
  Future<CachedMapTile?> getTile(String url) async => _tiles[url];

  @override
  Future<void> putTile({
    required String url,
    required CachedMapTileMetadata metadata,
    Uint8List? bytes,
  }) async {
    _tiles[url] = (
      bytes: bytes ?? Uint8List(0),
      metadata: metadata,
    );
  }
}
