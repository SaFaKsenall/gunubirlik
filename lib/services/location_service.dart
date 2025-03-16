import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LocationService {
  final NetworkInfo _networkInfo = NetworkInfo();
  
  // Check if location permission is granted
  Future<bool> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission != LocationPermission.denied && 
           permission != LocationPermission.deniedForever;
  }
  
  // Get location for job
  Future<Map<String, dynamic>?> getLocationForJob() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izni reddedildi');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni kalıcı olarak reddedildi');
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı');
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.reduced,
          // ignore: deprecated_member_use
          timeLimit: const Duration(seconds: 10),
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        String neighborhood = 'Bilinmeyen Mahalle';
        if (placemarks.isNotEmpty) {
          // Debug print to see what values we're getting
          print('Raw placemark data: ${placemarks.first.toJson()}');
          
          // Mahalle bilgisini daha doğru almak için tüm olası alanları kontrol ediyoruz
          // Explicitly convert any numeric values to strings to avoid type issues
          String? subLocality = placemarks.first.subLocality;
          String? subAdministrativeArea = placemarks.first.subAdministrativeArea;
          String? locality = placemarks.first.locality;
          String? administrativeArea = placemarks.first.administrativeArea;
          
          // Ensure all values are strings
          // ignore: unnecessary_type_check
          if (subLocality != null && subLocality is! String) {
            subLocality = subLocality.toString();
          }
          // ignore: unnecessary_type_check
          if (subAdministrativeArea != null && subAdministrativeArea is! String) {
            subAdministrativeArea = subAdministrativeArea.toString();
          }
          // ignore: unnecessary_type_check
          if (locality != null && locality is! String) {
            locality = locality.toString();
          }
          // ignore: unnecessary_type_check
          if (administrativeArea != null && administrativeArea is! String) {
            administrativeArea = administrativeArea.toString();
          }
          
          neighborhood = subLocality ?? // Mahalle
              subAdministrativeArea ?? // İlçe
              locality ?? // Şehir
              administrativeArea ?? // Bölge
              'Bilinmeyen Mahalle';
          
          print('Konum bilgileri: Mahalle=$subLocality, ' +
                'İlçe=$subAdministrativeArea, ' +
                'Şehir=$locality, ' +
                'Bölge=$administrativeArea, ' +
                'Seçilen=$neighborhood');
        }

        Map<String, dynamic> locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': ServerValue.timestamp,
          'neighborhood': neighborhood,
          'accuracy': 'gps',
          'accuracyMeters': position.accuracy
        };

        return locationData;
      } catch (e) {
        print('GPS konum hatası: $e');
        String? wifiName = await _networkInfo.getWifiName();
        String? wifiBSSID = await _networkInfo.getWifiBSSID();

        if (wifiName != null && wifiBSSID != null) {
          // WiFi üzerinden konum tahmini yapmaya çalışalım
          try {
            // WiFi konum veritabanı kullanarak konum tahmini yapılabilir
            // Burada basit bir çözüm olarak WiFi adını kullanıyoruz
            String wifiLocation = wifiName.replaceAll('"', '');
            
            Map<String, dynamic> locationData = {
              'timestamp': ServerValue.timestamp,
              'wifiName': wifiName,
              'wifiBSSID': wifiBSSID,
              'accuracy': 'wifi',
              'neighborhood': wifiLocation
            };

            return locationData;
          } catch (wifiError) {
            print('WiFi konum hatası: $wifiError');
            Map<String, dynamic> locationData = {
              'timestamp': ServerValue.timestamp,
              'wifiName': wifiName,
              'wifiBSSID': wifiBSSID,
              'accuracy': 'wifi',
              'neighborhood': 'WiFi Bölgesi'
            };

            return locationData;
          }
        }

        throw Exception('Konum alınamadı');
      }
    } catch (e) {
      print('Konum alma hatası: $e');
      rethrow;
    }
  }
} 