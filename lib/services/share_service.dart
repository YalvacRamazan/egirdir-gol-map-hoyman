import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:map/models/basket_model.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Bir sepetin konum bilgilerini şablon mesaj olarak paylaşır.
  Future<void> shareBasket(BasketModel basket, {String? targetPhoneNumber}) async {
    final message = _formatBasketMessage(basket);

    if (targetPhoneNumber != null && targetPhoneNumber.isNotEmpty) {
      // Belirli bir numaraya direkt WhatsApp mesajı gönderimi
      final cleanPhone = targetPhoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final whatsappUrl = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}");
      final webUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
        return;
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
        return;
      }
    }

    // Numarasız veya WhatsApp yüklü değilse genel paylaşım menüsünü aç
    await Share.share(message, subject: '${basket.name} Konum Bilgisi');
  }

  /// Tüm sepetlerin verilerini yedekleme amaçlı toplu paylaşır.
  Future<void> shareBackup(List<BasketModel> baskets) async {
    if (baskets.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("📂 [GÖL SEPET TAKİP UYGULAMASI YEDEĞİ]");
    buffer.writeln("Tarih: ${DateTime.now().toLocal().toString().split('.')[0]}");
    buffer.writeln("Toplam Sepet Sayısı: ${baskets.length}");
    buffer.writeln("===================================\n");

    for (var i = 0; i < baskets.length; i++) {
      final b = baskets[i];
      buffer.writeln("${i + 1}. ${b.name}");
      buffer.writeln("A (Başlangıç): ${b.startLatitude.toStringAsFixed(6)}, ${b.startLongitude.toStringAsFixed(6)}");
      if (b.isCompleted) {
        buffer.writeln("B (Bitiş): ${b.endLatitude!.toStringAsFixed(6)}, ${b.endLongitude!.toStringAsFixed(6)}");
        buffer.writeln("Mesafe: ${b.distanceInMeters.toStringAsFixed(1)} metre");
        buffer.writeln("Süre: ${b.endTimestamp!.difference(b.startTimestamp).inMinutes} dk");
      } else {
        buffer.writeln("B (Bitiş): Kaydedilmedi (Yarım Sepet)");
      }
      buffer.writeln("-----------------------------------");
    }

    await Share.share(buffer.toString(), subject: 'Göl Sepet Takip Yedek');
  }

  /// Tek sepet için paylaşım metnini oluşturur.
  String _formatBasketMessage(BasketModel basket) {
    final buffer = StringBuffer();
    buffer.writeln("📍 *[GÖL SEPET BİLGİSİ]*");
    buffer.writeln("🏷️ *Sepet Adı:* ${basket.name}");
    buffer.writeln("📅 *Tarih:* ${_formatDateTime(basket.startTimestamp)}");
    buffer.writeln("🟢 *A Noktası (Başlangıç):*");
    buffer.writeln("   Konum: `${basket.startLatitude.toStringAsFixed(6)}, ${basket.startLongitude.toStringAsFixed(6)}`");
    buffer.writeln("   Harita: https://maps.google.com/?q=${basket.startLatitude},${basket.startLongitude}");
    
    if (basket.isCompleted && basket.endLatitude != null && basket.endLongitude != null) {
      buffer.writeln("🔴 *B Noktası (Bitiş):*");
      buffer.writeln("   Konum: `${basket.endLatitude!.toStringAsFixed(6)}, ${basket.endLongitude!.toStringAsFixed(6)}`");
      buffer.writeln("   Harita: https://maps.google.com/?q=${basket.endLatitude},${basket.endLongitude}");
      buffer.writeln("📏 *Sepet Uzunluğu:* ~${basket.distanceInMeters.toStringAsFixed(1)} metre");
      
      if (basket.endTimestamp != null) {
        final duration = basket.endTimestamp!.difference(basket.startTimestamp);
        buffer.writeln("⏱️ *Serim Süresi:* ${duration.inMinutes} dakika");
      }
    } else {
      buffer.writeln("⚠️ *B Noktası:* Henüz yerleştirilmedi.");
    }
    
    return buffer.toString();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return "$day/$month/$year $hour:$minute";
  }
}
