import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class FirestoreService {
  CollectionReference get _alertsCollection =>
      FirebaseFirestore.instance.collection('alerts');

  // Yeni siren/uyarı konumu kaydet
  Future<void> addAlert(LatLng location, String description) async {
    await _alertsCollection.add({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Kayıtlı tüm uyarıları canlı akış (Stream) olarak getir
  Stream<QuerySnapshot> getAlerts() {
    return _alertsCollection.snapshots();
  }
}