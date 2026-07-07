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
          ? const Center(
              child: Text(
                'Henüz kayıtlı sepet bulunmuyor.\nHarita üzerinden yeni sepet ekleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
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
                        ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
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

  Widget _buildStatusBadge(BasketModel basket) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: basket.isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        basket.isCompleted ? 'Tamamlandı' : 'Açık (Yarım)',
        style: TextStyle(
          color: basket.isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (basket.id != null) {
                viewModel.deleteBasket(basket.id!);
              }
              Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
