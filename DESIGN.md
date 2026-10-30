# DESIGN.md — Göl Sepet Takip

Bu dosya uygulamanın tasarım yönünü belgeler. antislop filtresi bu yönün üzerine uygulanır.
Kararlar mevcut uygulamadan türetilmiştir; sahibi tarafından güncellenebilir.

## Kimlik

- **Ürün:** Göl Sepet Takip. Eğirdir/Hoyman Gölü'nde sepet (ağ) konumlarını A ve B noktası olarak kaydeden, mesafeyi ölçen ve WhatsApp ile paylaşan saha aracı.
- **Kullanıcı:** Göl üzerinde çalışan saha kullanıcısı. Cihaz: düşük donanımlı Android (J7 Prime hedefi). Kullanım: açık havada, gündüz, tek elle.
- **Karakter:** Sade, işlevsel, harita-öncelikli. Süsleme değil, okunabilirlik ve hız.

## Dial değerleri

- **ENERGY 1** (sakin): Saha aracı; dikkat dağıtan görsel enerji yok.
- **RHYTHM 1** (tekdüze): Ekranlar tutarlı; kullanıcı her seferinde aynı yeri arar.
- **MOTION 1** (yalnızca durum geçişleri): Sonsuz animasyon yok; yalnızca Material geçişleri.

## Palet

Aktif palet: 3 çekirdek + 1 vurgu + nötr. (R-29)

| Rol | Renk | Gerekçe |
|---|---|---|
| Çekirdek (birincil) | `#1565C0` (blue.shade800) | Göl/su çağrışımı; harita ve birincil eylemler. |
| Çekirdek (anlamsal) | `green.shade800` | A noktası = başlangıç. Anlamsal, sabit. |
| Çekirdek (anlamsal) | `red.shade800` | B noktası = bitiş. Anlamsal, sabit. |
| Vurgu | `#BF360C` (deepOrange.shade900) | Uyarılar ve GPS Boost aktif durumu. Tek vurgu, dikkat anlarında. |
| Nötr | gri tonları | Zemin, ikincil metin, pasif kontroller. |

- Yeşil/kırmızı A/B noktası için anlamsaldır, dekorasyon değil (R-31).
- Amber (eski boost rengi) kaldırıldı; vurguya birleştirildi (R-29).

## Tipografi

- **Yazı tipi:** Platform varsayılanı (Android'de Roboto).
- **Gerekçe:** Çevrimdışı güvenilirlik (ağdan font indirme yok), düşük donanımda hızlı render, küçük ekranda yüksek okunabilirlik, yerel his. (R-06)
- Ölçek: gövde 13-16, başlık 16 bold, büyük sayı 20 bold.

## Tema

- **Açık + koyu tema**, Ayarlar ekranından geçiş (Sistem / Açık / Koyu). (R-21)
- **Gerekçe:** Birincil senaryo gündüz açık hava (açık tema), ancak akşam/gece kullanımı için koyu tema gerekli. Her iki tema da WCAG AA kontrastını geçer. (R-34)

## Kontrast

- Tüm metin WCAG AA: normal metin 4.5:1, büyük metin 3:1, arayüz bileşenleri 3:1. (R-25)
- Durum rozetleri koyu zemin + beyaz metin kullanır (her iki temada geçer).

## Paylaşım mesajı emoji kullanımı

- WhatsApp paylaşım metni emoji içerir (📍🏷️📅 vb.).
- **Gerekçe:** Bu metin uygulama arayüzü değil, sohbet mesajıdır; emoji alıcının hızlı taramasını kolaylaştırır ve WhatsApp'ta yaygın bir konvansiyondur. Bilinçli bir karardır. (R-04)

## Bilinen sınırlar

- Harita altlığı OpenStreetMap; çevrimdışı için SQLite tile önbelleği kullanılır.
- Uygulama logosu/ikonu bu belgenin kapsamı dışındadır; mevcut varsayılan ikon korunur.
