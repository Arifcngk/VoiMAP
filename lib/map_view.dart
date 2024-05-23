import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:sliding_up_panel/sliding_up_panel.dart';
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
  List<String> _steps = [];

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
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
      List<String> steps = [];
      for (var route in routes) {
        var startLatLng = LatLng(
            route['start_location']['lat'], route['start_location']['lng']);
        var endLatLng =
            LatLng(route['end_location']['lat'], route['end_location']['lng']);
        routePoints.add(startLatLng);
        routePoints.add(endLatLng);
        var instruction =
            route['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), '');
        // Türkçe çeviri
        instruction = _translateInstruction(instruction);
        steps.add(instruction);
      }
      // Yönlendirme adımlarını harita üzerinde göster
      _showRouteOnMap(routePoints);
      setState(() {
        _steps = steps;
      });
    } else {
      setState(() {
        message = "Yol tarifi alınamadı.";
      });
    }
  }

  String _translateInstruction(String instruction) {
    // Türkçe çeviri
    instruction = instruction.replaceAll("turn", "dön");
    instruction = instruction.replaceAll("left", "sola");
    instruction = instruction.replaceAll("right", "sağa");
    instruction = instruction.replaceAll("Continue", "Devam et");
    instruction = instruction.replaceAll("onto", "üzerinden");
    instruction = instruction.replaceAll("Destination", "Hedef");
    instruction = instruction.replaceAll("At the roundabout", "Kavşakta");
    instruction = instruction.replaceAll("take the", "alın");
    instruction = instruction.replaceAll("turn", "dönüş");
    instruction = instruction.replaceAll("onto", "üzerinden");
    instruction = instruction.replaceAll("Destination", "Hedef");
    instruction = instruction.replaceAll("At the roundabout", "Kavşakta");
    instruction = instruction.replaceAll("exit", "çıkış");
    instruction = instruction.replaceAll("head", "baş");
    instruction = instruction.replaceAll("Head", "Baş");
    instruction = instruction.replaceAll("north", "kuzey");
    instruction = instruction.replaceAll("south", "güney");
    instruction = instruction.replaceAll("west", "batı");
    instruction = instruction.replaceAll("east", "doğu");
    instruction = instruction.replaceAll("northwest", "kuzeybatı");
    instruction = instruction.replaceAll("northeast", "kuzeydoğu");
    instruction = instruction.replaceAll("southwest", "güneybatı");
    instruction = instruction.replaceAll("southeast", "güneydoğu");
    instruction = instruction.replaceAll("turn right", "sağa dön");
    instruction = instruction.replaceAll("on the right", "sağında");
    instruction = instruction.replaceAll("go straight", "düz git");
    instruction = instruction.replaceAll("on", "üzerinde");

    instruction =
        instruction.replaceAll("head north", "kuzeye doğru ilerleyin");
    instruction =
        instruction.replaceAll("head south", "güneye doğru ilerleyin");
    instruction = instruction.replaceAll("head west", "bata doğru ilerleyin");
    instruction =
        instruction.replaceAll("head east on", "doğuya doğru ilerleyin");

    return instruction;
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

  void _startListening() async {
    bool available = await speech.initialize(
      onStatus: (status) {
        print("Durum: $status");
      },
      onError: (error) {
        print("Hata: $error");
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
                      target: LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
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
          SlidingUpPanel(
            panel: Column(
              children: [
                _steps.isEmpty
                    ? Center(child: Text(""))
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _steps.length,
                          itemBuilder: (BuildContext context, int index) {
                            String instruction = _steps[index];
                            return ListTile(
                              leading: Icon(Icons.directions_walk),
                              title: Text(instruction),
                            );
                          },
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
              ],
            ),
            minHeight: 120, // Panelin başlangıç yüksekliğini artırdık
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            body: Container(),
          ),
        ],
      ),
    );
  }
}
