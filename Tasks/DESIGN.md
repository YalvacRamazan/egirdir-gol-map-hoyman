# DESIGN.md - Göl Sepet Takip

Bu dosya uygulamanın tasarım yönünü ve güncel ürün kapsamını belgeler. antislop filtresi bu yönün üzerine uygulanır.
Kararlar mevcut uygulamadan ve güncel gereksinimlerden türetilmiştir; sahibi tarafından güncellenebilir.

## Kimlik

- **Ürün:** Göl Sepet Takip. Eğirdir/Hoyman Gölü'nde A ve B noktalarını kaydeden, A noktasından B noktasına tekne rotasyonunu hesaplayan, kullanıcının baktığı yönü haritada gösteren ve rota bilgisini WhatsApp ile paylaşan saha aracı.
- **Kullanıcı:** Göl üzerinde çalışan saha kullanıcısı. Cihaz: Android'in tüm sürümlerini destekleme gereksinimi; düşük donanımlı cihazlar ve J7 Prime önceliği. Kullanım: açık havada, gündüz, tek elle.
- **Karakter:** Sade, işlevsel, harita-öncelikli. Süsleme değil, okunabilirlik ve hız.

## İşlevsel kapsam

### Harita ve önbellek

- Harita altlığı OpenStreetMap verisi ve OpenStreetMap araçlarıyla internetten render edilir.
- Haritanın tamamı cihaza toplu olarak indirilmez. Kullanıcı haritada gezindikçe gerekli tile'lar ağdan yüklenir.
- Tile önbelleği RAM ve diskte sınırlı tutulur. Boyut/yaş sınırı, eski tile temizliği ve doluluk durumunda temizleme davranışı tanımlanır; telefonun belleği sürekli büyüyen bir harita deposuna dönüşmez.
- Çevrimdışı durumda yalnızca daha önce önbelleğe alınmış tile'lar kullanılabilir. Tam harita çevrimdışı kullanımı bu kapsamın dışındadır.
- OpenStreetMap atıf bilgisi harita üzerinde görünür.

### Rota ve yön

- Kullanıcı A (başlangıç) ve B (bitiş) noktalarını haritadan seçip kaydeder.
- A ve B koordinatlarından A→B hedef yön açısı (bearing) hesaplanır. Cihazın geçerli yönü biliniyorsa hedef yön ile mevcut yön arasındaki en kısa açı farkı, teknenin dönmesi gereken rotasyon olarak gösterilir.
- A/B işaretleri, rota çizgisi ve hesaplanan rotasyon harita üzerinde gösterilir.
- Kullanıcının/cihazın o anda baktığı yön ayrı bir okla gösterilir. Bu ok, A→B hedef rotasyonundan bağımsız olarak okunur.
- Harita üzerindeki canlı pusula kuzey, güney, doğu ve batı yönlerini gösterir ve cihazın yönü değiştikçe anlık güncellenir.
- Konum veya yön verisi alınamadığında ok ve pusula için veri olmadığı kullanıcıya bildirilir.

### İsimlendirme ve WhatsApp paylaşımı

- Kullanıcı A ve B noktalarına ayrı ayrı isim atayabilir.
- Paylaşım mesajı nokta isimlerini, A/B koordinatlarını, A→B hedef yönünü ve hesaplanan rotasyonu içerir.
- Kullanıcı paylaşımı başlattığında oluşturulan metin WhatsApp'a aktarılır. Uygulama kullanıcı adına otomatik mesaj göndermez.

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
| Vurgu | `#BF360C` (deepOrange.shade900) | Uyarılar ve konum/yön sensörü hataları. Tek vurgu, dikkat anlarında. |
| Nötr | gri tonları | Zemin, ikincil metin, pasif kontroller. |

- Yeşil/kırmızı A/B noktası için anlamsaldır, dekorasyon değil (R-31).
- Vurgu rengi yalnızca uyarı ve hata durumlarında kullanılır (R-29).

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

- WhatsApp paylaşım metni; A/B nokta isimlerini, koordinatları, hedef yönü ve rotasyonu emoji ile bölümlere ayırabilir (📍🏷️🧭 vb.).
- **Gerekçe:** Bu metin uygulama arayüzü değil, sohbet mesajıdır; emoji alıcının hızlı taramasını kolaylaştırır ve WhatsApp'ta yaygın bir konvansiyondur. Bilinçli bir karardır. (R-04)

## Bilinen sınırlar

- Harita altlığı OpenStreetMap tabanlıdır ve internetten render edilir. Hoyman Gölü bölgesi (bbox, zoom 10-15) kalıcı tile deposu olarak cihaza indirilebilir; bölge dışı tile'lar sınırlı geçici önbellekte tutulur.
- Canlı yön oku ve pusula, cihazın konum/yön sensörü verilerinin kullanılabilirliğine bağlıdır.
- Android'in tüm sürümlerini destekleme gereksinimi, seçilen Flutter/Android toolchain'i ve eklentilerin minimum API sınırlarıyla birlikte doğrulanmalıdır.
- Uygulama logosu/ikonu bu belgenin kapsamı dışındadır; mevcut varsayılan ikon korunur.

## Uygulama taskı

Android'in tüm sürümlerini desteklemesi gereken, OpenStreetMap tabanlı haritayı internetten render eden ve tile önbelleğini sınırlı tutan bir Android saha uygulaması geliştir. Uygulama A ve B noktalarını kaydedip A→B hedef yönünü ve teknenin dönmesi gereken rotasyonu hesaplayacak. Kullanıcının baktığı yönü haritada bir okla, anlık yönü ise kuzey/güney/doğu/batı gösteren canlı pusulayla sunacak. Kullanıcı A/B noktalarını isimlendirip rota bilgisini WhatsApp mesajı olarak paylaşabilecek. Harita, önbellek ve sensör kullanımı düşük donanımlı cihazlarda da kontrollü kaynak tüketimi sağlayacak.

## İş listesi

- [ ] Android'in tüm sürümlerini destekle. Minimum SDK, Flutter sürümü, eklentiler ve sensör API'leri için uyumluluğu doğrula; toolchain'in izin vermediği sürümleri açıkça raporla.
- [ ] OpenStreetMap verisi ve araçlarıyla çevrimiçi harita render akışını kur; atıf bilgisini göster.
- [ ] Görünür bölge için tile yükleme, sınırlı RAM/disk önbelleği, eski tile temizliği ve ağ hatası davranışını uygula.
- [ ] A/B noktası seçme, kaydetme ve isimlendirme akışını oluştur.
- [ ] A→B bearing hesabını ve mevcut yöne göre en kısa dönüş açısını hesapla; rota çizgisi, hedef yön ve rotasyon göstergesini haritaya ekle.
- [ ] Kullanıcının baktığı yönü gösteren oku ve kuzey/güney/doğu/batı etiketli canlı pusulayı haritaya ekle; sensör verisi yoksa durum göster.
- [ ] Nokta isimlerini, koordinatları ve rotasyon bilgisini içeren WhatsApp mesajı oluşturma ve kullanıcı onayıyla paylaşma akışını kur.
- [ ] Farklı Android sürümlerinde ve düşük donanımlı cihazlarda harita akıcılığını, RAM/depolama kullanımını, konum/yön izinlerini ve WhatsApp paylaşımını test et.
