import 'package:flutter/material.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/share_service.dart';
import 'package:map/services/sqlite_tile_cache_service.dart';
import 'package:map/viewmodels/map_viewmodel.dart';

class AyarlarEkran extends StatefulWidget {
  final MapViewModel viewModel;

  const AyarlarEkran({super.key, required this.viewModel});

  @override
  State<AyarlarEkran> createState() => _AyarlarEkranState();
}

class _AyarlarEkranState extends State<AyarlarEkran> {
  final _settingsService = SettingsService();
  final _phoneController = TextEditingController();
  double _accuracyThreshold = 15.0;
  String _themeMode = 'system';
  CacheStats? _cacheStats;
  bool _cacheError = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = _settingsService.settings.backupPhoneNumber;
    _accuracyThreshold = _settingsService.settings.gpsAccuracyThreshold;
    _themeMode = _settingsService.settings.themeMode;
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() => _cacheError = false);
    try {
      final stats = await SqliteTileCacheService().getStats();
      if (mounted) setState(() => _cacheStats = stats);
    } catch (_) {
      if (mounted) setState(() => _cacheError = true);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final updatedSettings = AppSettings(
      backupPhoneNumber: _phoneController.text.trim(),
      gpsAccuracyThreshold: _accuracyThreshold,
      themeMode: _themeMode,
    );

    await _settingsService.saveSettings(updatedSettings);
    widget.viewModel.updateAccuracyThreshold(_accuracyThreshold);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar başarıyla kaydedildi.')),
      );
      Navigator.pop(context);
    }
  }

  /// Tema modunu anında uygular ve kalıcı olarak kaydeder.
  Future<void> _changeThemeMode(String value) async {
    setState(() => _themeMode = value);
    await _settingsService.saveSettings(
      AppSettings(
        backupPhoneNumber: _phoneController.text.trim(),
        gpsAccuracyThreshold: _accuracyThreshold,
        themeMode: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- GÖRÜNÜM BÖLÜMÜ ---
            _sectionTitle(context, 'Görünüm'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tema',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gece kullanımı için koyu temayı seçebilirsiniz.',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('Sistem')),
                        ButtonSegment(value: 'light', label: Text('Açık')),
                        ButtonSegment(value: 'dark', label: Text('Koyu')),
                      ],
                      selected: {_themeMode},
                      onSelectionChanged: (selection) =>
                          _changeThemeMode(selection.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- GÜVENLİK VE VERİ DEPOLAMA BÖLÜMÜ ---
            _sectionTitle(context, 'Güvenlik ve Veri Depolama'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verileriniz güvende. Bu uygulama hiçbir harici sunucuya veri göndermez. Tüm bilgiler yerel veritabanınızda saklanır.',
                            style: TextStyle(fontSize: 13, color: scheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Yedekleme Numarası / Grup Numarası',
                        hintText: 'Örn: +905051234567',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        helperText: 'Sepet konumları otomatik paylaşıldığında bu numara hedeflenir.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- GPS VE PİL OPTİMİZASYONU BÖLÜMÜ ---
            _sectionTitle(context, 'GPS ve Pil Ayarları (J7 Prime Uyumlu)'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kabul Edilebilir GPS Doğruluğu: ${_accuracyThreshold.toStringAsFixed(0)} metre',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu değerden daha yüksek sapmaya sahip konumlar sepet kaydında engellenir.',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    Slider(
                      value: _accuracyThreshold,
                      min: 5.0,
                      max: 50.0,
                      divisions: 9,
                      label: '${_accuracyThreshold.toStringAsFixed(0)}m',
                      onChanged: (value) {
                        setState(() {
                          _accuracyThreshold = value;
                        });
                      },
                    ),
                    const Divider(height: 20),
                    // --- HARİTA ÖNBELLEĞİ BİLGİ KARTI ---
                    Row(
                      children: [
                        Icon(Icons.map_outlined, size: 20, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Harita Önbelleği',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (_cacheError)
                                Text(
                                  'Önbellek bilgisi alınamadı.',
                                  style: TextStyle(fontSize: 12, color: scheme.error),
                                )
                              else
                                Text(
                                  _cacheStats == null
                                      ? 'Yükleniyor...'
                                      : '${_cacheStats!.tileCount} tile · ${_cacheStats!.formattedSize}',
                                  style: TextStyle(
                                      fontSize: 12, color: scheme.onSurfaceVariant),
                                ),
                              Text(
                                'Gezilen harita alanları otomatik kaydedilir.',
                                style: TextStyle(
                                    fontSize: 11, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (_cacheError)
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: scheme.primary),
                            onPressed: _loadCacheStats,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Yeniden Dene'),
                          )
                        else
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: scheme.error),
                            onPressed: _cacheStats == null || _cacheStats!.tileCount == 0
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Önbelleği Temizle'),
                                        content: Text(
                                          '${_cacheStats!.tileCount} tile (${_cacheStats!.formattedSize}) silinecek. Devam?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('İptal'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: scheme.error,
                                                foregroundColor: scheme.onError),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Temizle'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await SqliteTileCacheService().clearAll();
                                      await _loadCacheStats();
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                            content: Text('Harita önbelleği temizlendi.')),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Temizle'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- MANUEL YEDEKLEME VE VERİ YÖNETİMİ ---
            _sectionTitle(context, 'Veri Yönetimi'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (widget.viewModel.baskets.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yedeklenecek kayıtlı sepet bulunmamaktadır.')),
                    );
                    return;
                  }
                  ShareService().shareBackup(widget.viewModel.baskets);
                },
                icon: const Icon(Icons.backup),
                label: const Text('Tüm Sepet Geçmişini Dışa Aktar (Yedekle)'),
              ),
            ),
            const SizedBox(height: 30),

            // --- KAYDET BUTONU ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _saveSettings,
                child: const Text(
                  'Ayarları Kaydet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
