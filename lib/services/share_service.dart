import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:map/models/basket_model.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Bir sepetin konum bilgilerini şablon mesaj olarak paylaşır.
  ///
  /// [currentHeading] verilirse mesaja A→B hedef yönüne göre hesaplanan
  /// rotasyon satırı eklenir; verilmezse rotasyon "yön verisi yok" görünür.
  /// Mesaj doğrudan gönderilmez; WhatsApp/sistem paylaşım akışı kullanıcı
  /// onayıyla açılır.
  Future<void> shareBasket(
    BasketModel basket, {
    String? targetPhoneNumber,
    double? currentHeading,
  }) async {
    final message = formatBasketMessage(basket, currentHeading: currentHeading);

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
    await SharePlus.instance.share(
      ShareParams(text: message, subject: '${basket.name} Konum Bilgisi'),
    );
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
      // is_completed=1 olsa bile end_* alanları NULL kalabilir; null-safe oku
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

  /// Tek sepet için paylaşım metnini oluşturur.
  ///
  /// DESIGN.md gereği mesajda nokta isimleri, A/B koordinatları, A→B hedef
  /// yönü ve (heading veriliyorsa) hesaplanan rotasyon yer alır.
  /// [currentHeading] null ise rotasyon satırı "yön verisi yok" olur.
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

  /// İşaretli rotasyon açısını Türkçe yön metnine çevirir.
  /// Pozitif: saat yönü (sağa), negatif: saat yönünün tersi (sola).
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
