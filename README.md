# depo_yonetim

# CaveApp: Akıllı Mağara Depolama ve IoT Yönetim Sistemi 🚀

CaveApp; özellikle Kapadokya ve Niğde bölgesindeki doğal mağara depolarının verimliliğini artırmak, ürün kayıplarını en aza indirmek ve geleneksel depoculuğu modern IoT (Nesnelerin İnterneti) teknolojileriyle dijitalleştirmek amacıyla geliştirilmiş bütünleşik bir platformdur.

## 📌 Proje Hakkında

Doğal mağara depoları; patates, limon ve narenciye gibi ürünlerin muhafaza edilmesi için ideal soğuk hava depolarıdır. Ancak bu depoların fiziksel yapısı gereği içerideki sıcaklık, nem ve ışık dengesinin takibi oldukça zordur. CaveApp, bu sorunu çözmek için ESP tabanlı sensör üniteleri, Python Flask tabanlı bir sunucu ve modern bir Flutter mobil uygulamasını bir araya getirir.

Uygulama, sadece bir izleme aracı değil; aynı zamanda stok yönetimi, piyasa analizi, ihracat puanlaması ve karbon ayak izi takibi yapan kapsamlı bir işletme yönetim panelidir.

## 🛠 Teknolojik Stack

Proje, modern ve ölçeklenebilir bir mimari üzerine kurulmuştur:

-   **Mobil Uygulama:** Flutter & Dart (iOS ve Android)
-   **Backend/API:** Python & Flask
-   **Veri Yönetimi:** Shared Preferences (Yerel Saklama) & JSON API üzerinden Gerçek Zamanlı Veri
-   **Donanım/IoT:** ESP8266/ESP32, DHT11/22 (Sıcaklık ve Nem), LDR (Işık) sensörleri
-   **Grafik ve UI:** Fl Chart, Lucide Icons, Flutter Map (OpenStreetMap entegrasyonu)

## 🔄 Çalışma Mantığı ve Mimari

Sistem üç temel katmandan oluşmaktadır:

1.  **Donanım Katmanı (IoT):** Deponun farklı noktalarına yerleştirilen ESP üniteleri, ortamdaki sıcaklık, nem ve ışık verilerini anlık olarak okur. Bu veriler Wi-Fi üzerinden merkezi sunucuya POST isteği ile iletilir.
2.  **Sunucu Katmanı (Flask):** Python üzerinde koşan API, sensörlerden gelen verileri toplar, işler ve mobil uygulamanın erişebileceği bir yapıya (`/verileri_getir`) dönüştürür.
3.  **Mobil Uygulama Katmanı (Flutter):** Uygulama, her 5 saniyede bir sunucuya GET isteği göndererek en güncel verileri çeker. Eğer veriler belirlenen kritik eşiklerin dışındaysa, kullanıcıya anlık bildirim gönderir.

## ✨ Temel Özellikler

### 📊 Canlı İzleme Paneli (Dashboard)
Uygulamanın ana ekranı, tüm depoların genel durumunu veya seçilen deponun detaylı verilerini görselleştirir. Dairesel ilerleme çubukları ve canlı istatistik kartları ile deponun "sağlık durumu" anlık olarak takip edilebilir.

### 🔔 Akıllı Bildirim Sistemi
Sistem sadece veri göstermez, aynı zamanda verileri yorumlar. Donma riski, yüksek sıcaklık veya ürünlerde yeşillenmeye neden olabilecek yüksek ışık seviyelerinde kullanıcıyı anlık bildirimlerle uyarır.

### 📈 Stok ve Ürün Yönetimi
Kullanıcılar depoya giren ürün partilerini (patates, limon, greyfurt vb.) miktar, alış fiyatı ve giriş tarihlerine göre kaydedebilir. Bar grafikler üzerinden deponun doluluk oranları otomatik olarak hesaplanır.

### 🌍 Harita Entegrasyonu
OpenStreetMap altyapısı kullanılarak tüm depolar harita üzerinde konumlandırılır. Farklı coğrafi konumlardaki depoların durumunu görmek ve yönetmek tek bir dokunuşla mümkündür.

### 💰 Piyasa ve İhracat Analizi
Uygulama, güncel piyasa fiyatlarını ve döviz kurlarını takip eder. **İhracat Puanı** algoritması; ürünün depoda kalma süresi ve maliyet analizini piyasa değeriyle karşılaştırarak kullanıcıya stratejik satış önerileri sunar.

### 🌿 Karbon Ayak İzi Takibi
Sürdürülebilirlik vizyonu çerçevesinde, depolama sürecindeki veriler üzerinden işletmenin karbon ayak izi hesaplaması yapılır.

## 🚀 Kurulum ve Çalıştırma

### 1. API Sunucusunun Başlatılması
Gerekli kütüphaneleri kurun ve Python sunucusunu çalıştırın:
### 2. Flutter Uygulamasının Çalıştırma
### 3. Donanım Bağlantısı
ESP cihazınızın kodundaki SERVER_URL kısmına Flask sunucunuzun IP adresini girin. Sensör bağlantılarını yaptıktan sonra cihazı depoya yerleştirin.

## 👥 Katkıda Bulunanlar
Bu proje, *Kapadokya/Niğde Hackathon* kapsamında tarım teknolojilerini dijitalleştirmek amacıyla geliştirilmiştir.

---
CaveApp - Geleceğin Tarımı, Doğanın Kalbinde.
. Gerçek Zamanlı Rota Analizi (OSRM Entegrasyonu)
Uygulama, kuş uçuşu mesafe yerine OSRM (Open Source Routing Machine) altyapısını kullanır.
•
Siz haritadan bir hedef seçtiğinizde, uygulama seçtiğiniz deponun koordinatları ile hedef koordinatları arasında karayolu rotası çizer.
•
Hesaplama, bu gerçek yol mesafesi (km) üzerinden yapılır.
2. Akıllı Araç Önerisi (Coğrafi Mantık)
CarbonService.dart içerisindeki suggestOptimalVehicle fonksiyonu, coğrafi konumlara göre en çevreci/mantıklı aracı önerir:
•
Liman Yakınlığı Analizi: Eğer hem çıkış deponuz hem de varış noktanız büyük liman şehirlerine (İzmir, Mersin, İstanbul vb.) 150 km'den yakınsa ve mesafe 400 km'den fazlaysa, sistem otomatik olarak "Deniz Yolu" önerir.
•
Mesafe ve Yük Dengesi: Mesafe 200 km'den fazla ve yük 30 tondan ağırsa "Demiryolu", 800 km'den uzak ve yük hafifse (hızlı teslimat gereksinimi varsayılarak) "Hava Kargo" önerilir.
3. Dinamik Emisyon Formülü
Karbon salınımı şu formülle hesaplanır:
(Mesafe × Ağırlık × Araç Katsayısı) + (Mesafe × Aracın Boş Emisyonu)
•
Araç Katsayıları (kg CO2 / ton-km): Deniz yolu (0.015) en düşük, hava kargo (0.500) en yüksek emisyona sahiptir.
•
Boş Emisyon: Aracın yükü olmasa bile sadece yolu kat etmesinden kaynaklanan sabit salınım da hesaba katılır (Hava Kargo için km başına 1.5 kg, Tır için 0.25 kg).
4. Çevresel ve Ekonomik Etki Dönüşümü
Hesaplanan kg CO2 verisi, kullanıcıya daha anlamlı gelmesi için şu verilere dönüştürülür:
•
Ağaç Karşılığı: Bu salınımı nötrlemek için kaç yetişkin ağacın bir yıl boyunca çalışması gerektiği (1 ağaç ≈ 20 kg CO2).
•
Yakıt Sarfiyatı: Aracın tipine göre harcayacağı tahmini litre yakıt.
•
Karbon Vergisi (EU ETS): Avrupa Birliği standartlarındaki karbon fiyatlandırması (kg başına ~0.07€) üzerinden, lojistiğin potansiyel karbon maliyeti TL, USD ve EUR cinsinden canlı döviz kurlarıyla hesaplanır.
5. Görselleştirme
•
Harita: flutter_map kullanılarak çizilen rota çizgisi (Polyline).
•
Analiz Paneli: Hesaplamanın hangi matematiksel formülle yapıldığını kullanıcıya şeffaf bir şekilde gösteren "Hesaplama Formülü" bölümü.
Özetle; uygulama sadece bir hesap makinesi değil, harita üzerindeki iki nokta arasındaki lojistik senaryoyu simüle eden bir karar destek sistemidir.



