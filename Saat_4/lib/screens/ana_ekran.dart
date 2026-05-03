import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/depo.dart';
import '../models/satis_kaydi.dart';
import '../models/urun_partisi.dart';
import '../models/piyasa_degeri.dart';
import '../services/notification_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import 'satis_ozeti_ekrani.dart';
import 'urun_giris_ekrani.dart';
import 'piyasa_ekrani.dart';
import 'ihracat_puani_ekrani.dart';
import 'harita_ekrani.dart';
import 'bildirimler_ekrani.dart';
import 'ayarlar_ekrani.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  List<Depo> _depolar = [];
  String? _secilenDepoId; // Seçilen depo ID'si (null = Genel Durumu)

  List<SatisKaydi> _satislar = [];
  Map<String, List<UrunPartisi>> _depoUrunleri = {};
  late List<PiyasaDegeri> _piyasalar;
  late List<Sirket> _sirketler;
  Timer? _veriGuncellemeTimer;
  final Map<String, Set<String>> _aktifUyarilar = {};
  String _dil = 'tr';

  @override
  void initState() {
    super.initState();
    _piyasalar = PiyasaVerisi.ornekPiyasaDegerleri();
    _sirketler = PiyasaVerisi.ornekSirketler();
    _veriYukle();
    _dilYukle();
    NotificationService.load();
    // Register callback so notifications refresh the UI
    NotificationService.onYeniBildirim = () {
      if (mounted) setState(() {});
    };
    _zamanliGuncellemeBaslat();
  }

  Future<void> _veriYukle() async {
    final data = await DataService.loadAll();
    if (mounted) {
      setState(() {
        if (data['depolar'] != null && (data['depolar'] as List).isNotEmpty) {
          _depolar = List<Depo>.from(data['depolar']);
        }
        if (data['depoUrunleri'] != null && (data['depoUrunleri'] as Map).isNotEmpty) {
          _depoUrunleri = Map<String, List<UrunPartisi>>.from(data['depoUrunleri']);
        }
        if (data['satislar'] != null && (data['satislar'] as List).isNotEmpty) {
          _satislar = List<SatisKaydi>.from(data['satislar']);
        }
      });
    }
  }

  Future<void> _veriKaydet() async {
    await DataService.saveAll(
      depolar: _depolar,
      depoUrunleri: _depoUrunleri,
      satislar: _satislar,
    );
  }

  Future<void> _dilYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final dil = prefs.getString('dil') ?? 'tr';
    setState(() { _dil = dil; dilAyarla(dil); });
  }

  void _sensorUyariKontrol(Depo depo) {
    _aktifUyarilar.putIfAbsent(depo.id, () => {});
    final uyarilar = _aktifUyarilar[depo.id]!;

    if (depo.sicaklik > 20.0) {
      if (!uyarilar.contains('sicaklik_yuksek')) {
        NotificationService.showNotification(t('KRİTİK SICAKLIK'), '${depo.ad}: ${t('Sıcaklık')} ${depo.sicaklik.toStringAsFixed(1)}°C ${t('ile çok yüksek!')}', isKritik: true);
        uyarilar.add('sicaklik_yuksek');
      }
    } else if (depo.sicaklik < 2.0) {
      if (!uyarilar.contains('sicaklik_dusuk')) {
        NotificationService.showNotification(t('DONMA RİSKİ'), '${depo.ad}: ${t('Sıcaklık')} ${depo.sicaklik.toStringAsFixed(1)}°C ${t('seviyesine düştü!')}', isKritik: true);
        uyarilar.add('sicaklik_dusuk');
      }
    } else {
      uyarilar.remove('sicaklik_yuksek');
      uyarilar.remove('sicaklik_dusuk');
    }

    if (depo.nem < 70.0) {
      if (!uyarilar.contains('nem_dusuk')) {
        NotificationService.showNotification(t('DÜŞÜK NEM'), '${depo.ad}: ${t('Nem')} %${depo.nem.toStringAsFixed(0)} ${t('seviyesine düştü.')}', isKritik: false);
        uyarilar.add('nem_dusuk');
      }
    } else if (depo.nem > 96.0) {
      if (!uyarilar.contains('nem_yuksek')) {
        NotificationService.showNotification(t('YÜKSEK NEM'), '${depo.ad}: ${t('Nem')} %${depo.nem.toStringAsFixed(0)}. ${t('Çürüme riski!')}', isKritik: false);
        uyarilar.add('nem_yuksek');
      }
    } else {
      uyarilar.remove('nem_dusuk');
      uyarilar.remove('nem_yuksek');
    }

    if (depo.isik > 600.0) {
      if (!uyarilar.contains('isik_yuksek')) {
        NotificationService.showNotification(t('IŞIK UYARISI'), '${depo.ad}: ${t('Işık')} ${depo.isik.toStringAsFixed(0)} lux. ${t('Yeşillenme riski!')}', isKritik: false);
        uyarilar.add('isik_yuksek');
      }
    } else {
      uyarilar.remove('isik_yuksek');
    }
  }

  void _zamanliGuncellemeBaslat() {
    _veriGuncellemeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        PiyasaVerisi.piyasaGuncelle(_piyasalar);
        for (var depo in _depolar) {
          depo.rastgeleVeriUret();
          _sensorUyariKontrol(depo);
          final partiler = _depoUrunleri[depo.id];
          if (partiler != null) {
            depo.urunPuanlariniGuncelle(partiler, _piyasalar);
          }
        }
      });
      _veriKaydet();
    });
  }

  @override
  void dispose() {
    _veriGuncellemeTimer?.cancel();
    NotificationService.onYeniBildirim = null;
    super.dispose();
  }

  Depo? _getSecilenDepo() {
    if (_secilenDepoId == null) return null;
    try {
      return _depolar.firstWhere((d) => d.id == _secilenDepoId);
    } catch (e) {
      return null;
    }
  }

  double get _toplamKapasite {
    if (_secilenDepoId == null) {
      // Genel Durumu
      return _depolar.isEmpty ? 1 : _depolar.fold(0.0, (sum, d) => sum + d.kapasite);
    } else {
      // Seçili depo
      final depo = _getSecilenDepo();
      return depo?.kapasite ?? 1;
    }
  }

  double get _toplamDolu {
    if (_secilenDepoId == null) {
      // Genel Durumu
      return _depolar.fold(0.0, (sum, d) {
        final partiler = _depoUrunleri[d.id] ?? [];
        return sum + partiler.fold(0.0, (s, p) => s + p.miktar);
      });
    } else {
      // Seçili depo
      final partiler = _depoUrunleri[_secilenDepoId] ?? [];
      return partiler.fold(0.0, (s, p) => s + p.miktar);
    }
  }

  double get _ortalamaSicaklik {
    if (_depolar.isEmpty) return 0;
    if (_secilenDepoId == null) {
      // Genel Durumu
      return _depolar.map((d) => d.sicaklik).reduce((a, b) => a + b) / _depolar.length;
    } else {
      // Seçili depo
      final depo = _getSecilenDepo();
      return depo?.sicaklik ?? 0;
    }
  }

  double get _ortalamaIsik {
    if (_depolar.isEmpty) return 0;
    if (_secilenDepoId == null) {
      // Genel Durumu
      return _depolar.map((d) => d.isik).reduce((a, b) => a + b) / _depolar.length;
    } else {
      // Seçili depo
      final depo = _getSecilenDepo();
      return depo?.isik ?? 0;
    }
  }

  double get _ortalamaNem {
    if (_depolar.isEmpty) return 0;
    if (_secilenDepoId == null) {
      // Genel Durumu
      return _depolar.map((d) => d.nem).reduce((a, b) => a + b) / _depolar.length;
    } else {
      // Seçili depo
      final depo = _getSecilenDepo();
      return depo?.nem ?? 0;
    }
  }

  Widget _buildDepoSelectionPanel() {
    final selectedDepo = _getSecilenDepo();
    final bool isGenel = _secilenDepoId == null;
    final dolulukYuzdesi = (_toplamDolu / max(1.0, _toplamKapasite) * 100).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(t('Depo Seçimi'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        _buildDepoSecimi(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.panelDecoration(blur: 15),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGenel ? t('Genel Depo Durumu') : selectedDepo?.ad ?? t('Depo'),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isGenel ? t('Tüm tesislerin ortalama verileri') : selectedDepo?.konum ?? t('Konum belirtilmedi'),
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildCircularProgress(dolulukYuzdesi),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildDepoInfoStat(t('Kapasite'), '${_toplamKapasite.toStringAsFixed(0)} t', LucideIcons.database, AppTheme.primaryColor)),
                  Expanded(child: _buildDepoInfoStat(t('Dolu'), '${_toplamDolu.toStringAsFixed(0)} t', LucideIcons.package, AppTheme.accentColor)),
                  Expanded(child: _buildDepoInfoStat(t('Doluluk'), '${dolulukYuzdesi.toStringAsFixed(1)}%', LucideIcons.pieChart, Colors.orange)),
                ],
              ),
              const Divider(height: 32, color: AppTheme.surfaceLight),
              Row(
                children: [
                  Expanded(child: _buildDepoInfoStat(t('Sıcaklık'), '${_ortalamaSicaklik.toStringAsFixed(1)}°C', LucideIcons.thermometer, AppTheme.temperatureColor)),
                  Expanded(child: _buildDepoInfoStat(t('Nem'), '%${_ortalamaNem.toStringAsFixed(0)}', LucideIcons.droplets, AppTheme.humidityColor)),
                  Expanded(child: _buildDepoInfoStat(t('Işık'), '${_ortalamaIsik.toStringAsFixed(0)} lx', LucideIcons.sun, AppTheme.lightColor)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(double percent) {
    return SizedBox(
      height: 50,
      width: 50,
      child: Stack(
        children: [
          Center(
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 6,
              backgroundColor: AppTheme.surfaceLight,
              color: percent > 90 ? AppTheme.dangerColor : AppTheme.primaryColor,
            ),
          ),
          Center(child: Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildDepoInfoStat(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildDepoSecimi() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildDepoSecimKarti(null, t('Genel Durumu'), LucideIcons.layoutGrid),
          ..._depolar.map((d) => _buildDepoSecimKarti(d.id, d.ad, LucideIcons.warehouse)),
        ],
      ),
    );
  }

  Widget _buildDepoSecimKarti(String? id, String label, IconData icon) {
    final isSelected = _secilenDepoId == id;
    return GestureDetector(
      onTap: () => setState(() => _secilenDepoId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.cardBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.primaryLight : AppTheme.surfaceLight, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }


  Widget _buildDrawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(t(title), style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        if (title == 'İzleme') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PiyasaEkrani(piyasalar: _piyasalar, sirketler: _sirketler)));
        } else if (title == 'Raporlar') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => IhracatPuaniEkrani(depolar: _depolar, depoUrunleri: _depoUrunleri, sirketler: _sirketler)));
        } else if (title == 'Satış Özeti') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SatisOzetiEkrani(satislar: _satislar, depoUrunleri: _depoUrunleri, depoAdlari: _depolar.map((d) => d.ad).toList(), onKaydet: (s) { setState(() => _satislar = s); _veriKaydet(); }, onDepoUrunleriGuncelle: (yeni) { setState(() => _depoUrunleri = yeni); _veriKaydet(); })));
        } else if (title == 'Harita') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => HaritaEkrani(depolar: _depolar, onDepoEkle: (depo) { setState(() { _depolar.add(depo); _depoUrunleri[depo.id] = []; }); _veriKaydet(); })));
        } else if (title == 'Bildirimler') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BildirimlerEkrani()));
        } else if (title == 'Depolar') {
          _depoYonetimDialog(context);
        } else if (title == 'Ayarlar') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AyarlarEkrani(mevcutDil: _dil, onDilDegistir: (yeniDil) { setState(() { _dil = yeniDil; dilAyarla(yeniDil); }); })));
        }
      },
    );
  }

  void _depoYonetimDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: Row(
            children: [
              const Icon(LucideIcons.settings2, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Text(t('Depo Yönetimi'), style: const TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: _depolar.isEmpty 
              ? Padding(padding: const EdgeInsets.all(20), child: Text(t('Henüz depo yok.'))) 
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _depolar.length,
                  itemBuilder: (context, index) {
                    final depo = _depolar[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(depo.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(depo.konum, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('${t('Kapasite')}: ', style: const TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Slider(
                                    value: depo.kapasite,
                                    min: 100,
                                    max: 2000,
                                    divisions: 19,
                                    label: '${depo.kapasite.toStringAsFixed(0)} t',
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: (v) {
                                      setState(() => depo.kapasite = v);
                                      setDialogState(() {});
                                      _veriKaydet();
                                    },
                                  ),
                                ),
                                Text('${depo.kapasite.toStringAsFixed(0)} t', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.trash2, color: AppTheme.dangerColor),
                          onPressed: () {
                            setState(() {
                              _depolar.removeAt(index);
                              _depoUrunleri.remove(depo.id);
                              if (_secilenDepoId == depo.id) _secilenDepoId = null;
                            });
                            _veriKaydet();
                            setDialogState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Kapat'), style: const TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  void _urunEkleModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UrunGirisEkrani(
        depolar: _depolar,
        depoUrunleri: _depoUrunleri,
        onKaydet: (yeniDepoUrunleri) {
          setState(() {
            _depoUrunleri = yeniDepoUrunleri;
          });
          _veriKaydet();
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, IconData icon, Color iconColor) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 2 - 8,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.panelDecoration(blur: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(t(title), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Icon(icon, color: iconColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(t(subtitle), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(blur: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Depo Doluluk Durumu (%)'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Expanded(
            child: _depolar.isEmpty ? Center(child: Text(t('Depo bulunamadı'))) : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (barTouchResponse?.spot != null) {
                      final x = barTouchResponse!.spot!.touchedBarGroupIndex;
                      if (x >= 0 && x < _depolar.length) {
                        setState(() {
                          _secilenDepoId = _depolar[x].id;
                        });
                      }
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _depolar.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(_depolar[value.toInt()].ad.substring(0, min(4, _depolar[value.toInt()].ad.length)), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 20,
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_depolar.length, (index) {
                  final depo = _depolar[index];
                  final partiler = _depoUrunleri[depo.id] ?? [];
                  final doluMiktar = partiler.fold(0.0, (s, p) => s + p.miktar);
                  final dolulukYuzdesi = (doluMiktar / max(1.0, depo.kapasite) * 100).clamp(0.0, 100.0);
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: dolulukYuzdesi,
                        color: dolulukYuzdesi > 90 ? AppTheme.dangerColor : AppTheme.accentColor,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(blur: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Canlı Depo Haritası'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(38.62, 34.71),
                  initialZoom: 7,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.depo_yonetim',
                  ),
                  MarkerLayer(
                    markers: _depolar.where((d) => d.lat != null && d.lng != null).map((depo) {
                      return Marker(
                        point: LatLng(depo.lat!, depo.lng!),
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.location_on, color: AppTheme.dangerColor, size: 20),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Embedded notification panel for the main screen
  Widget _buildBildirimPaneli() {
    final sonBildirimler = NotificationService.bildirimler.take(3).toList();
    if (sonBildirimler.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(blur: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bell, color: AppTheme.dangerColor, size: 18),
              const SizedBox(width: 8),
              Text(t('Son Bildirimler'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (NotificationService.bildirimler.length > 3)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BildirimlerEkrani())),
                  child: Text(t('Tümünü Gör'), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...sonBildirimler.map((b) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: b.kritikMi ? AppTheme.dangerColor.withValues(alpha: 0.08) : AppTheme.surfaceColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: b.kritikMi ? AppTheme.dangerColor.withValues(alpha: 0.3) : AppTheme.surfaceLight, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  b.kritikMi ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                  color: b.kritikMi ? AppTheme.dangerColor : AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.baslik, style: TextStyle(color: b.kritikMi ? AppTheme.dangerColor : AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(b.icerik, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(
                  '${b.tarih.hour}:${b.tarih.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(t('Nevşehir Depo'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.scaffoldBackground,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.surfaceColor),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.mountain, color: AppTheme.primaryColor, size: 40),
                    const SizedBox(height: 8),
                    const Text('NEVŞEHİR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
            _buildDrawerItem(LucideIcons.home, 'Ana Sayfa'),
            _buildDrawerItem(LucideIcons.warehouse, 'Depolar'),
            _buildDrawerItem(LucideIcons.map, 'Harita'),
            _buildDrawerItem(LucideIcons.activity, 'İzleme'),
            _buildDrawerItem(LucideIcons.fileText, 'Raporlar'),
            _buildDrawerItem(LucideIcons.bell, 'Bildirimler'),
            _buildDrawerItem(LucideIcons.receipt, 'Satış Özeti'),
            const Spacer(),
            _buildDrawerItem(LucideIcons.settings, 'Ayarlar'),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                image: const DecorationImage(
                  image: AssetImage('assets/arkaplan.jpg'),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [AppTheme.scaffoldBackground.withValues(alpha: 0.8), AppTheme.scaffoldBackground.withValues(alpha: 0.1)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('CaveApp', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(t('Mağara Depoları Yönetimi'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Depo Seçim Kontrol Paneli
                  _buildDepoSelectionPanel(),
                  const SizedBox(height: 16),
                  // Embedded Notifications
                  _buildBildirimPaneli(),
                  if (NotificationService.bildirimler.isNotEmpty) const SizedBox(height: 16),
                  Wrap(
                    children: [
                      _buildSummaryCard('Depo', '${_depolar.length}', 'Toplam', LucideIcons.home, AppTheme.primaryColor),
                      _buildSummaryCard('Kapasite', '${_toplamKapasite.toStringAsFixed(0)} t', 'Toplam', LucideIcons.box, AppTheme.primaryColor),
                      _buildSummaryCard('Dolu', '${_toplamDolu.toStringAsFixed(0)} t', '%${(_toplamDolu/max(1, _toplamKapasite)*100).toStringAsFixed(0)}', LucideIcons.layers, AppTheme.primaryColor),
                      _buildSummaryCard('Sıcaklık', '${_ortalamaSicaklik.toStringAsFixed(1)}°', 'Ort', LucideIcons.thermometer, AppTheme.humidityColor),
                      _buildSummaryCard('Nem', '%${_ortalamaNem.toStringAsFixed(0)}', 'Ort', LucideIcons.droplets, AppTheme.humidityColor),
                      _buildSummaryCard('Işık', '${_ortalamaIsik.toStringAsFixed(0)} lx', 'Ort', LucideIcons.sun, AppTheme.lightColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBarChart(),
                  const SizedBox(height: 16),
                  _buildMapWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _urunEkleModal(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }
}
