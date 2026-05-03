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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



