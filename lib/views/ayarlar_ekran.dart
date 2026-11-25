import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:map/services/region_downloader.dart';
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
  bool _autoBoostEnabled = true;
  bool _proximityAlertEnabled = true;
  double _proximityThreshold = 25.0;

  @override
  void initState() {
    super.initState();
    _phoneController.text = _settingsService.settings.backupPhoneNumber;
    _accuracyThreshold = _settingsService.settings.gpsAccuracyThreshold;
    _themeMode = _settingsService.settings.themeMode;
    _autoBoostEnabled = _settingsService.settings.autoBoostEnabled;
    _proximityAlertEnabled = _settingsService.settings.proximityAlertEnabled;
    _proximityThreshold = _settingsService.settings.proximityThreshold;
  }

  String _backupStatusText() {
    if (kIsWeb) {
      return 'Yedek: uygulama belgeleri klasöründe (sepetler.json)';
    }
    return 'Yedek: uygulama özel belgeler klasöründe (GolSepetTakip/sepetler.json)';
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
      autoBoostEnabled: _autoBoostEnabled,
      proximityAlertEnabled: _proximityAlertEnabled,
      proximityThreshold: _proximityThreshold,
    );

    await _settingsService.saveSettings(updatedSettings);
    widget.viewModel.updateAccuracyThreshold(_accuracyThreshold);
    widget.viewModel.configureProximity(
      enabled: _proximityAlertEnabled,
      threshold: _proximityThreshold,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar başarıyla kaydedildi.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _changeThemeMode(String value) async {
    setState(() => _themeMode = value);
    await _settingsService.saveSettings(
      AppSettings(
        backupPhoneNumber: _phoneController.text.trim(),
        gpsAccuracyThreshold: _accuracyThreshold,
        themeMode: value,
        autoBoostEnabled: _autoBoostEnabled,
        proximityAlertEnabled: _proximityAlertEnabled,
        proximityThreshold: _proximityThreshold,
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
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
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
                      maxLength: 20,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required maxLength,
                        required isFocused,
                      }) =>
                          null,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Yedekleme Numarası / Grup Numarası',
                        hintText: 'Örn: +905051234567',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        helperText:
                            'E.164 biçiminde (+ülke kodu) girin; geçersiz numara WhatsApp paylaşımını atlar.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle(context, 'GPS ve Pil Ayarları'),
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
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Pil seviyesine göre otomatik GPS modu',
                      ),
                      subtitle: const Text(
                        'Pil %50\'nin üstündeyse yüksek doğruluk, altındaysa '
                        'tasarruf modu kullanılır. Kapatırsanız GPS modunu '
                        'elle seçersiniz.',
                      ),
                      value: _autoBoostEnabled,
                      onChanged: (v) => setState(() => _autoBoostEnabled = v),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.map_outlined,
                            size: 20, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Harita',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Hoyman Gölü bölgesindeki tile\'lar cihaza '
                                'kalıcı kaydedilir; bölge dışı tile\'lar 50MB '
                                'geçici önbellekte tutulur.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    ListenableBuilder(
                      listenable: RegionDownloader().progress,
                      builder: (context, _) {
                        final p = RegionDownloader().progress.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: p?.running == true
                                    ? () => RegionDownloader().cancel()
                                    : () => unawaited(RegionDownloader()
                                        .downloadRegion(
                                            SqliteTileCacheService())),
                                icon: Icon(p?.running == true
                                    ? Icons.cancel
                                    : Icons.download),
                                label: Text(p?.running == true
                                    ? 'İndirmeyi Durdur'
                                    : 'Hoyman Gölü Haritasını Cihaza İndir'),
                              ),
                            ),
                            if (p?.running == true) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value:
                                    p!.total == 0 ? null : p.done / p.total,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p.done}/${p.total} tile',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ] else if (p != null && !p.running)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Sonuç: ${p.done} tile indirildi, '
                                  '${p.failed} hatalı.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 20),

            _sectionTitle(context, 'Konum Takibi ve Uyarılar'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hedefe yaklaşınca uyar'),
                      subtitle: const Text(
                        'Seçili A/B noktasına belirtilen mesafede inince '
                        'uyarı verir.',
                      ),
                      value: _proximityAlertEnabled,
                      onChanged: (v) =>
                          setState(() => _proximityAlertEnabled = v),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Uyarı Mesafesi',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 10, label: Text('10 m')),
                        ButtonSegment(value: 25, label: Text('25 m')),
                        ButtonSegment(value: 50, label: Text('50 m')),
                      ],
                      selected: {_proximityThreshold},
                      onSelectionChanged: (s) =>
                          setState(() => _proximityThreshold = s.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle(context, 'Veri Yönetimi'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.folder_copy,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _backupStatusText(),
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
