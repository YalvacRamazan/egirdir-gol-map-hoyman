import 'package:flutter/material.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/share_service.dart';
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
  bool _enableTileCaching = true;

  @override
  void initState() {
    super.initState();
    _phoneController.text = _settingsService.settings.backupPhoneNumber;
    _accuracyThreshold = _settingsService.settings.gpsAccuracyThreshold;
    _enableTileCaching = _settingsService.settings.enableTileCaching;
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
      enableTileCaching: _enableTileCaching,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- GÜVENLİK VE VERİ DEPOLAMA BÖLÜMÜ ---
            const Text(
              'Güvenlik ve Veri Depolama',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security, color: Colors.green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verileriniz güvende. Bu uygulama hiçbir harici sunucuya veri göndermez. Tüm bilgiler yerel veritabanınızda saklanır.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
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
            const Text(
              'GPS ve Pil Ayarları (J7 Prime Uyumlu)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                      title: const Text('Haritayı Önbelleğe Al (Çevrimdışı Desteği)'),
                      subtitle: const Text('Görüntülenen harita alanlarını çevrimdışı kullanım için kaydeder.'),
                      value: _enableTileCaching,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          _enableTileCaching = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- MANUEL YEDEKLEME VE VERİ YÖNETİMİ ---
            const Text(
              'Veri Yönetimi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
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
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
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
}
