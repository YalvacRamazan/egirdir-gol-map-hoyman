import 'package:flutter/material.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/share_service.dart';
import 'package:map/viewmodels/map_viewmodel.dart';

class KatalogSayfasi extends StatelessWidget {
  final MapViewModel viewModel;
  final String? backupPhoneNumber;

  const KatalogSayfasi({
    super.key,
    required this.viewModel,
    this.backupPhoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sepet Kataloğu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Tümünü Yedekle',
            onPressed: () {
              if (viewModel.baskets.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yedeklenecek sepet bulunamadı.')),
                );
                return;
              }
              ShareService().shareBackup(viewModel.baskets);
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return viewModel.baskets.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              itemCount: viewModel.baskets.length,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemBuilder: (context, index) {
                final basket = viewModel.baskets[index];
                final isSelected = viewModel.selectedBasket?.id == basket.id;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            basket.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _buildStatusBadge(basket),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      key: ValueKey('sub_${basket.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Başlangıç: ${_formatDateTime(basket.startTimestamp)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (basket.isCompleted) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Mesafe: ${basket.distanceInMeters.toStringAsFixed(1)} metre',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.green),
                          tooltip: 'Paylaş',
                          onPressed: () {
                            ShareService().shareBasket(
                              basket,
                              targetPhoneNumber: backupPhoneNumber,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Sil',
                          onPressed: () => _confirmDelete(context, basket),
                        ),
                      ],
                    ),
                    onTap: () {
                      viewModel.selectBasket(basket);
                      Navigator.pop(context); // Harita ekranına geri dön
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${basket.name} haritada gösteriliyor.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                );
              },
            );
        },
      ),
    );
  }

  /// Kayıtlı sepet yokken gösterilen boş durum: nedeni ve sonraki adımı söyler.
  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Henüz kayıtlı sepet bulunmuyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Harita üzerinde A noktasında kaydı başlatıp B noktasında bitirerek yeni sepet ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.map),
              label: const Text('Haritaya Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BasketModel basket) {
    // Koyu zemin + beyaz metin: her iki temada da WCAG AA kontrastını geçer.
    final background =
        basket.isCompleted ? Colors.green.shade800 : Colors.deepOrange.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        basket.isCompleted ? 'Tamamlandı' : 'Açık (Yarım)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  void _confirmDelete(BuildContext context, BasketModel basket) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sepeti Sil'),
        content: Text('${basket.name} sepetini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () {
              if (basket.id != null) {
                viewModel.deleteBasket(basket.id!);
              }
              Navigator.pop(context);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
