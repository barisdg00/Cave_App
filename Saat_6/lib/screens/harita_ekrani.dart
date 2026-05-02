import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/depo.dart';
import '../theme/app_theme.dart';
import 'ayarlar_ekrani.dart';

class HaritaEkrani extends StatefulWidget {
  final List<Depo> depolar;
  final Function(Depo) onDepoEkle;

  const HaritaEkrani({
    super.key,
    required this.depolar,
    required this.onDepoEkle,
  });

  @override
  State<HaritaEkrani> createState() => _HaritaEkraniState();
}

class _HaritaEkraniState extends State<HaritaEkrani> {
  final MapController _mapController = MapController();

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _yeniDepoDialog(point.latitude, point.longitude);
  }

  void _yeniDepoDialog(double lat, double lng) {
    final adController = TextEditingController();
    final konumController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: Text(
            t('Yeni Depo Ekle'),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adController,
                decoration: InputDecoration(labelText: t('Depo Adı')),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: konumController,
                decoration: InputDecoration(labelText: t('Konum Adı')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t('İptal'),
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: () {
                if (adController.text.isNotEmpty) {
                  final depo = Depo(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    ad: adController.text,
                    konum: konumController.text,
                    lat: lat,
                    lng: lng,
                  );
                  widget.onDepoEkle(depo);
                  Navigator.pop(context);
                }
              },
              child: Text(
                t('Ekle'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          t('Depo Haritası'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(38.9637, 35.2433),
              initialZoom: 6,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.depo_yonetim',
              ),
              MarkerLayer(
                markers: widget.depolar
                    .where((d) => d.lat != null && d.lng != null)
                    .map((depo) {
                      return Marker(
                        point: LatLng(depo.lat!, depo.lng!),
                        width: 120,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                depo.ad,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: AppTheme.dangerColor,
                              size: 30,
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t('Haritaya dokunarak depo ekleyebilirsiniz'),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
