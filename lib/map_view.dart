import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapViewPage extends StatefulWidget {
  @override
  _MapViewPageState createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  late stt.SpeechToText speech;
  late bool isListening;
  late String message;
  Position? _currentPosition;
  late GoogleMapController mapController;
  Set<Polyline> _polylines = {};
  String apiKey = 'AIzaSyBdua_dTYkZDsyqyxCO9jMArgJcOb7yvF8';

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
    isListening = false;
    message = "Seni Dinliyorum...";
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        message = "Konum servisleri etkin değil.";
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          message = "Konum izinleri reddedildi.";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        message = "Konum izinleri kalıcı olarak reddedildi.";
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
      // Konum alındıktan sonra haritayı kullanıcının konumuna odakla
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 19.0,
            tilt: 45,
            bearing: 90,
          ),
        ),
      );
    });
  }

  void _getDirections(String destination) async {
    if (_currentPosition == null) {
      setState(() {
        message = "Mevcut konum alınamadı.";
      });
      return;
    }

    var origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    var url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey&mode=walking';

    var response = await http.get(Uri.parse(url));
    var jsonResponse = json.decode(response.body);

    if (jsonResponse['status'] == 'OK') {
      // Yol tarifini ayrıntılı olarak işle
      var routes = jsonResponse['routes'][0]['legs'][0]['steps'];
      List<LatLng> routePoints = [];
      for (var route in routes) {
        var startLatLng = LatLng(
            route['start_location']['lat'], route['start_location']['lng']);
        var endLatLng =
            LatLng(route['end_location']['lat'], route['end_location']['lng']);
        routePoints.add(startLatLng);
        routePoints.add(endLatLng);
      }
      // Yönlendirme adımlarını harita üzerinde göster
      _showRouteOnMap(routePoints);
      _showDirections(routes);
    } else {
      setState(() {
        message = "Yol tarifi alınamadı.";
      });
    }
  }

  void _showRouteOnMap(List<LatLng> routePoints) {
    Set<Polyline> polylines = {};
    polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: routePoints,
      color: Colors.blue,
      width: 5,
    ));
    setState(() {
      _polylines = polylines;
      message = "Yol tarifi gösterildi.";
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showDirections(List<dynamic> steps) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Yön Tarifi"),
          ),
          body: ListView.builder(
            itemCount: steps.length,
            itemBuilder: (BuildContext context, int index) {
              String instruction = steps[index]['html_instructions'];
              return ListTile(
                leading: Icon(Icons.directions_walk),
                title: Text(instruction),
              );
            },
          ),
        );
      },
    );
  }

  void _startListening() async {
    bool available = await speech.initialize(
      onStatus: (status) {
        print("onStatus: $status");
      },
      onError: (error) {
        print("onError: $error");
      },
    );
    if (available) {
      setState(() {
        isListening = true;
      });
      speech.listen(
        onResult: (result) {
          setState(() {
            message = result.recognizedWords.isNotEmpty
                ? result.recognizedWords
                : "Anlaşılamadı";
            if (result.recognizedWords.isNotEmpty) {
              // Hedef adresi almak için yönlendirme işlevini burada çağırın
              _getDirections(result.recognizedWords);
            }
          });
        },
        listenFor: const Duration(seconds: 10),
      );
    } else {
      setState(() {
        isListening = false;
      });
      speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text("SESLİ ADIMLARLA YÖNLENDİRME"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(0, 0),
              zoom: 19.0,
              tilt: 45,
              bearing: 90,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              // Harita oluşturulduktan sonra konumu kontrol et
              if (_currentPosition != null) {
                mapController.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      zoom: 19.0,
                      tilt: 45,
                      bearing: 90,
                    ),
                  ),
                );
              }
            },
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    backgroundColor: Colors.black,
                    onPressed: _startListening,
                    child: Icon(isListening ? Icons.mic : Icons.mic_none),
                    elevation: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
