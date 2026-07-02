import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  factory TileCacheService() => _instance;
  TileCacheService._internal();

  Directory? _cacheDirectory;

  Future<void> init() async {
    if (kIsWeb) return; // Web üzerinde dosya sistemi olmadığı için önbellekleme devre dışı
    
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory(p.join(docDir.path, 'map_tiles'));
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }
    } catch (e) {
      // Hata durumunda önbellekleme devre dışı kalır
      _cacheDirectory = null;
    }
  }

  Directory? get cacheDirectory => _cacheDirectory;
}

class CachedTileProvider extends TileProvider {
  final Directory cacheDir;
  final HttpClient _httpClient = HttpClient();

  CachedTileProvider({required this.cacheDir}) {
    _httpClient.connectionTimeout = const Duration(seconds: 10);
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    
    final file = File(p.join(
      cacheDir.path,
      coordinates.z.toString(),
      coordinates.x.toString(),
      '${coordinates.y}.png',
    ));

    if (file.existsSync()) {
      return FileImage(file);
    }

    _downloadAndCacheTile(url, file);

    return NetworkImage(
      url,
      headers: headers,
    );
  }

  Future<void> _downloadAndCacheTile(String url, File file) async {
    try {
      await file.parent.create(recursive: true);

      final uri = Uri.parse(url);
      final request = await _httpClient.getUrl(uri);
      
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
        await file.writeAsBytes(bytes);
      }
    } catch (e) {
      // Çevrimdışı hatası veya yazma hatasında yoksay
    }
  }
}
