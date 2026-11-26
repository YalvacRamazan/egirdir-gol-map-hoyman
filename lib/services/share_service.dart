import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:map/models/basket_model.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Sepet bilgisini paylaşır. Alıcı seçimi WhatsApp'a bırakılır: uygulama
  /// numara zorunluluğu aramaz, WhatsApp'ın paylaşım ekranı açılır ve
  /// kullanıcı grup ya da kişiyi kendisi seçer. WhatsApp kurulu değilse
  /// wa.me bağlantısı, o da açılmazsa sistem paylaşım sayfası kullanılır.
  Future<void> shareBasket(
    BasketModel basket, {
    double? currentHeading,
  }) async {
    final message = formatBasketMessage(basket, currentHeading: currentHeading);

    // Numarasız whatsapp://send: WhatsApp açılır, alıcıyı kullanıcı seçer.
    final whatsappUrl = Uri.parse(
        'whatsapp://send?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
      return;
    }

    final webUrl =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      return;
    }

    await SharePlus.instance.share(
      ShareParams(text: message, subject: '${basket.name} Konum Bilgisi'),
    );
  }

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
      if (b.isCompleted && b.endLatitude != null && b.endLongitude != null) {
        buffer.writeln("B (Bitiş): ${b.endLatitude!.toStringAsFixed(6)}, ${b.endLongitude!.toStringAsFixed(6)}");
        buffer.writeln("Mesafe: ${b.distanceInMeters.toStringAsFixed(1)} metre");
        if (b.endTimestamp != null) {
          buffer.writeln("Süre: ${b.endTimestamp!.difference(b.startTimestamp).inMinutes} dk");
        }
      } else {
        buffer.writeln("B (Bitiş): Kaydedilmedi (Yarım Sepet)");
      }
      buffer.writeln("-----------------------------------");
    }

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: 'Göl Sepet Takip Yedek'),
    );
  }

  String formatBasketMessage(BasketModel basket, {double? currentHeading}) {
    final buffer = StringBuffer();
    buffer.writeln("📍 *[GÖL SEPET BİLGİSİ]*");
    buffer.writeln("🏷️ *Sepet Adı:* ${basket.name}");
    buffer.writeln("📅 *Tarih:* ${_formatDateTime(basket.startTimestamp)}");
    buffer.writeln("🟢 *A (Başlangıç):* ${basket.startDisplayName}");
    buffer.writeln("📍 *A Konum:* `${basket.startLatitude.toStringAsFixed(6)}, ${basket.startLongitude.toStringAsFixed(6)}`");
    buffer.writeln("   Harita: https://maps.google.com/?q=${basket.startLatitude},${basket.startLongitude}");

    if (basket.isCompleted && basket.endLatitude != null && basket.endLongitude != null) {
      buffer.writeln("🔴 *B (Bitiş):* ${basket.endDisplayName}");
      buffer.writeln("📍 *B Konum:* `${basket.endLatitude!.toStringAsFixed(6)}, ${basket.endLongitude!.toStringAsFixed(6)}`");
      buffer.writeln("   Harita: https://maps.google.com/?q=${basket.endLatitude},${basket.endLongitude}");
      buffer.writeln("📏 *Sepet Uzunluğu:* ~${basket.distanceInMeters.toStringAsFixed(1)} metre");

      final target = basket.initialBearing;
      if (target != null) {
        buffer.writeln("🧭 *Hedef Yön (A→B):* ${target.round()}°");
      }
      final rotation = basket.initialBearingFrom(currentHeading);
      if (rotation != null) {
        buffer.writeln("🔄 *Rotasyon:* ${_formatRotation(rotation)}");
      } else {
        buffer.writeln("🔄 *Rotasyon:* yön verisi yok");
      }

      if (basket.endTimestamp != null) {
        final duration = basket.endTimestamp!.difference(basket.startTimestamp);
        buffer.writeln("⏱️ *Serim Süresi:* ${duration.inMinutes} dakika");
      }
    } else {
      buffer.writeln("⚠️ *B Noktası:* Henüz yerleştirilmedi.");
    }

    return buffer.toString();
  }

  String _formatRotation(double rotation) {
    final rounded = rotation.round();
    if (rounded == 0) return "0° (hedefe dönük)";
    return rounded > 0
        ? "$rounded° sağa"
        : "${rounded.abs()}° sola";
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
