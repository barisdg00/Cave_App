import 'package:latlong2/latlong.dart';

class PointLatLng {
  final double lat;
  final double lng;
  PointLatLng(this.lat, this.lng);

  factory PointLatLng.fromLatLng(LatLng p) =>
      PointLatLng(p.latitude, p.longitude);
}

String encodePolyline(List<PointLatLng> points) {
  String encoded = '';
  int prevLat = 0, prevLng = 0;
  for (final point in points) {
    int lat = (point.lat * 1e5).round();
    int lng = (point.lng * 1e5).round();
    int dLat = lat - prevLat;
    int dLng = lng - prevLng;
    prevLat = lat;
    prevLng = lng;
    encoded += _encodeValue(dLat) + _encodeValue(dLng);
  }
  return encoded;
}

List<LatLng> decodePolyline(String encoded) {
  List<LatLng> poly = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    poly.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return poly;
}

String _encodeValue(int val) {
  val = val < 0 ? ~(val << 1) : val << 1;
  String encoded = '';
  while (val >= 0x20) {
    int rem = (0x20 | (val & 0x1f)) + 63;
    encoded += String.fromCharCode(rem);
    val >>= 5;
  }
  encoded += String.fromCharCode(val + 63);
  return encoded;
}
