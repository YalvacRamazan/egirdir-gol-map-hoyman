Flutter (`egirdir-gol-map-hoyman`) projesi için harita render sorununu çözecek ve veri/önbellek mimarisini netleştirecek düzenlemeleri adım adım yap. Bir adımı tamamlamadan diğerine geçme.

### 1. Harita Katmanı ve OpenStreetMap Yapılandırması
- Harita bileşeninde (`lib/views/harita_ekran.dart` ve ilgili ViewModel/servis katmanlarında) harita altlığı olarak **OpenStreetMap** kullan.
- `TileLayer` üzerinde `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (veya yapılandırılabilir tile URL) tanımla ve OpenStreetMap kullanım politikalarına uygun şekilde `userAgentPackageName` değerini (`com.rumata.map`) eksiksiz ver.
- Haritanın boş/gri render olmasına yol açabilecek eksik izinleri (`AndroidManifest.xml` içinde `INTERNET` izni), hatalı `TileProvider` bağlantısını veya boyut/layout kısıtlarını kontrol edip düzelt.

### 2. Veri Saklama Mimarisi (Güncel)
- **Sepet bilgisi** (`basket_model.dart` ve ilgili akış) ve **koordinat verileri** **SQLite** üzerinde saklanacak.
- **Harita tile'ları kalıcı olarak saklanmayacak**; sistem yükünü artırmamak için doğrudan internetten (OpenStreetMap) indirilecek ve yalnızca flutter_map'in bellek içi görüntü önbelleğinde tutulacak. `sqlite_tile_cache_service.dart` / `sqlite_tile_provider.dart` harita akışından çıkarıldı; dosyalar eski referans/test uyumu için repoda kalabilir.
- `database_service.dart` ve ilgili SQLite servislerinde tablo şemalarını, CRUD işlemlerini, indekslemeleri ve hata yönetimini gözden geçir; sepet verileri ve koordinat kayıtlarının tutarlı şekilde SQLite'a yazılıp okunmasını sağla.

### 3. Güvenlik Gereksinimleri
- Tüm harita ve dış ağ isteklerinde zorunlu olarak **HTTPS** kullan.
- OpenStreetMap karo isteklerinde gereksiz yük oluşturmamak için görünür bölge dışına önceden indirme yapma; yalnızca ekranda gereken tile'ları iste. Kullanıcıya ait hassas verileri veya kimlik bilgilerini tile URL'lerine/parametrelerine ekleme.
- Eğer harita veya harici servisler için API anahtarı kullanılıyorsa, anahtarı kaynak koda düz metin (`hardcoded`) olarak yazma; `--dart-define` / ortam değişkenleri ile yönet ve sağlayıcı tarafında paket adı / platform kısıtlaması uygulanmasını dikkate al.
- SQLite sorgularında parametre bağlama (parameterized queries / prepared statements) kullanarak SQL injection riskini önle ve yerel veritabanında hassas/gizli bilgi tutmamaya dikkat et.

### 4. Yeni Arayüz Özellikleri
- **Yan metreölçer:** Haritada seçili/aktif sepete olan anlık uzaklığı sol kenarda dikey bir ölçerle göster; değer GPS güncellemeleriyle canlı yenilensin.
- **Tahmini varış saati:** Anlık uzaklık ve GPS hızından (hız yoksa varsayılan tekne hızından) hesaplanan `~HH:mm` biçiminde küçük bir saat rozeti göster.
- **Kaydırmalı bar saati:** Harita üstünde yatay kaydırılabilir bir durum barı oluştur ve içinde güncel saati `HH:mm` biçiminde canlı göster; bar gereksiz yükseklik kaplamayacak ve harita jestlerini mümkün olduğunca engellemeyecek.

### Çalışma ve Anlatım Kuralları
- Her adımda önce ilgili dosyadaki mevcut kodu incele, yapılacak değişikliği kod üzerinden göster, uyguladıktan sonra doğrulama/test adımıyla adımı kapat; tamamlanmadan bir sonraki adıma geçme.