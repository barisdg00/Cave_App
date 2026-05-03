import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'polyline_utils.dart';

class CarbonService {
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';
  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _overpassUrl =
      'https://overpass-api.de/api/interpreter';
  static const String _localApiUrl = 'http://127.0.0.1:5001';

  static const Map<String, double> emissionFactors = {
    'Hava Kargo': 0.500,
    'Tır (Kara)': 0.100,
    'Demiryolu': 0.030,
    'Deniz Yolu': 0.015,
  };

  /// Araç adından rota modunu belirler
  static String vehicleToMode(String vehicle) {
    if (vehicle.contains('Hava')) return 'hava';
    if (vehicle.contains('Deniz')) return 'deniz';
    if (vehicle.contains('Demiryolu')) return 'demiryolu';
    return 'kara';
  }

  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_localApiUrl/geocode?address=${Uri.encodeComponent(address)}',
            ),
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LatLng(data['lat'], data['lng']);
      }
    } catch (_) {}
    try {
      final response = await http.get(
        Uri.parse(
          '$_nominatimBaseUrl?q=${Uri.encodeComponent(address)}&format=json&limit=1',
        ),
        headers: {'User-Agent': 'CaveApp_Hackathon_Project'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Rota seçeneklerini döner. Geçersiz mod için Exception fırlatır.
  static Future<List<Map<String, dynamic>>> getRouteOptions(
    LatLng start,
    LatLng end, {
    String mode = 'kara',
  }) async {
    if (mode == 'kara' || mode == 'demiryolu') {
      return _getOsrmRoutes(start, end, mode);
    } else if (mode == 'deniz') {
      return _getSeaRoute(start, end);
    } else if (mode == 'hava') {
      return _getAirRoute(start, end);
    }
    return _getOsrmRoutes(start, end, mode);
  }

  // ─── OSRM Karayolu / Demiryolu ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _getOsrmRoutes(
    LatLng start,
    LatLng end,
    String mode,
  ) async {
    try {
      final url =
          '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?overview=full&geometries=polyline&alternatives=true';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          return routes
              .map<Map<String, dynamic>>(
                (r) => {
                  'distanceKm': (r['distance'] as num) / 1000.0,
                  'durationMin': (r['duration'] as num) / 60.0,
                  'polyline': r['geometry'] as String,
                  'mode': mode,
                },
              )
              .toList();
        }
      }
    } catch (_) {}

    // OSRM başarısız → düz çizgi fallback (kara/demiryolu için kabul edilebilir)
    final d = const Distance().as(LengthUnit.Kilometer, start, end).toDouble();
    return [
      {
        'distanceKm': d,
        'durationMin': d * 1.5,
        'polyline': _straightLinePolyline(start, end),
        'mode': mode,
      },
    ];
  }

  // ─── Deniz Yolu ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _getSeaRoute(
    LatLng start,
    LatLng end,
  ) async {
    final startPort = await _findNearestPort(start);
    if (startPort == null) {
      throw Exception(
        'Çıkış noktasına yakın liman bulunamadı.\n'
        'Deniz yolu yalnızca kıyı şehirleri için kullanılabilir.',
      );
    }
    final endPort = await _findNearestPort(end);
    if (endPort == null) {
      throw Exception(
        'Varış noktasına yakın liman bulunamadı.\n'
        'Deniz yolu yalnızca kıyı şehirleri için kullanılabilir.',
      );
    }

    // Kara → Liman mesafesi (ilave rota)
    final toPort = const Distance().as(LengthUnit.Kilometer, start, startPort);
    final fromPort = const Distance().as(LengthUnit.Kilometer, endPort, end);
    final seaDistance = const Distance()
        .as(LengthUnit.Kilometer, startPort, endPort)
        .toDouble();
    final totalDistance = toPort + seaDistance + fromPort;

    // Deniz rotası polyline (liman → liman)
    final seaPoly = _greatCirclePolyline(startPort, endPort, steps: 30);

    return [
      {
        'distanceKm': totalDistance,
        'durationMin': seaDistance / 0.5, // ~30 km/h deniz hızı
        'polyline': seaPoly,
        'mode': 'deniz',
        'startWaypoint': startPort,
        'endWaypoint': endPort,
        'waypointLabel': 'Liman',
      },
    ];
  }

  // ─── Hava Yolu ────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _getAirRoute(
    LatLng start,
    LatLng end,
  ) async {
    final startAirport = await _findNearestAirport(start);
    if (startAirport == null) {
      throw Exception(
        'Çıkış noktasına yakın havalimanı bulunamadı.\n'
        'Hava kargo yalnızca havalimanı olan şehirler için kullanılabilir.',
      );
    }
    final endAirport = await _findNearestAirport(end);
    if (endAirport == null) {
      throw Exception(
        'Varış noktasına yakın havalimanı bulunamadı.\n'
        'Hava kargo yalnızca havalimanı olan şehirler için kullanılabilir.',
      );
    }

    final flightDistance = const Distance()
        .as(LengthUnit.Kilometer, startAirport, endAirport)
        .toDouble();

    final airPoly = _greatCirclePolyline(startAirport, endAirport, steps: 40);

    return [
      {
        'distanceKm': flightDistance,
        'durationMin': flightDistance / 800 * 60, // ~800 km/h
        'polyline': airPoly,
        'mode': 'hava',
        'startWaypoint': startAirport,
        'endWaypoint': endAirport,
        'waypointLabel': 'Havalimanı',
      },
    ];
  }

  // ─── Yardımcı: Overpass liman araması ─────────────────────────────────────

  static Future<LatLng?> _findNearestPort(LatLng pos) async {
    // Türkiye için 700km yeterli (Karadeniz, Ege, Akdeniz)
    const radius = 700000;
    final query =
        '[out:json][timeout:20];'
        '('
        'node["harbour"="yes"](around:$radius,${pos.latitude},${pos.longitude});'
        'node["seamark:type"="harbour"](around:$radius,${pos.latitude},${pos.longitude});'
        'node["landuse"="harbour"](around:$radius,${pos.latitude},${pos.longitude});'
        ');out 1;';
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_overpassUrl?data=${Uri.encodeComponent(query)}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final elements = jsonDecode(response.body)['elements'] as List?;
        if (elements != null && elements.isNotEmpty) {
          return LatLng(
            (elements[0]['lat'] as num).toDouble(),
            (elements[0]['lon'] as num).toDouble(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Yardımcı: Overpass havalimanı araması ────────────────────────────────

  static Future<LatLng?> _findNearestAirport(LatLng pos) async {
    // Önce ICAO kodlu büyük havalimanları, sonra tüm havalimanları
    const radius = 350000;
    final query =
        '[out:json][timeout:20];'
        '('
        'node["aeroway"="aerodrome"]["icao"](around:$radius,${pos.latitude},${pos.longitude});'
        'node["aeroway"="aerodrome"]["iata"](around:$radius,${pos.latitude},${pos.longitude});'
        'node["aeroway"="aerodrome"](around:$radius,${pos.latitude},${pos.longitude});'
        ');out 1;';
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_overpassUrl?data=${Uri.encodeComponent(query)}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final elements = jsonDecode(response.body)['elements'] as List?;
        if (elements != null && elements.isNotEmpty) {
          return LatLng(
            (elements[0]['lat'] as num).toDouble(),
            (elements[0]['lon'] as num).toDouble(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Polyline yardımcıları ────────────────────────────────────────────────

  /// Büyük daire interpolasyonu (hava/deniz rotası için)
  static String _greatCirclePolyline(
    LatLng start,
    LatLng end, {
    int steps = 20,
  }) {
    final List<PointLatLng> points = [];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      points.add(PointLatLng(
        start.latitude + t * (end.latitude - start.latitude),
        start.longitude + t * (end.longitude - start.longitude),
      ));
    }
    return encodePolyline(points);
  }

  /// Düz çizgi polyline (OSRM fallback)
  static String _straightLinePolyline(LatLng start, LatLng end) {
    return encodePolyline([
      PointLatLng(start.latitude, start.longitude),
      PointLatLng(end.latitude, end.longitude),
    ]);
  }

  // ─── Hesaplama fonksiyonları ──────────────────────────────────────────────

  static String suggestOptimalVehicle(double weightTons) {
    if (weightTons <= 10) return 'Tır (Kara)';
    if (weightTons <= 100) return 'Demiryolu';
    return 'Deniz Yolu';
  }

  static const Map<String, double> fuelFactors = {
    'Hava Kargo': 12.0,
    'Tır (Kara)': 0.35,
    'Demiryolu': 0.15,
    'Deniz Yolu': 0.05,
  };

  static double calculateFootprint({
    required double distanceKm,
    required double weightTons,
    required double factor,
  }) {
    return distanceKm * weightTons * factor;
  }

  static double calculateFuel(double distanceKm, String vehicle) {
    return distanceKm * (fuelFactors[vehicle] ?? 0.2);
  }

  static Future<Map<String, dynamic>?> calculateCarbonViaApi({
    required LatLng start,
    required LatLng end,
    required double weight,
    required String vehicle,
    String mode = 'kara',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_localApiUrl/calculate_carbon'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'start_lat': start.latitude,
              'start_lng': start.longitude,
              'end_lat': end.latitude,
              'end_lng': end.longitude,
              'weight': weight,
              'vehicle': vehicle,
              'mode': mode,
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return null;
  }

  /// Karbon fiyatı: ₺1.5/kg CO₂ (~₺1500/tonne, Türkiye gönüllü karbon piyasası)
  static const double carbonPricePerKg = 1.5;

  static double calculateCost(double kgCo2) => kgCo2 * carbonPricePerKg;

  static int calculateTrees(double kgCo2) => (kgCo2 / 20).ceil();
}
