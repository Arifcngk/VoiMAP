import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Navigation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late stt.SpeechToText speech;
  late bool isListening;
  late String message;
  Position? _currentPosition;
  late GoogleMapController mapController;
  Set<Polyline> _polylines = {};
  String apiKey =
      'AIzaSyBdua_dTYkZDsyqyxCO9jMArgJcOb7yvF8'; // Buraya kendi API anahtarınızı ekleyin

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
      polylineId: PolylineId('route'),
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
    List<Widget> directionsWidgets = [];
    for (var step in steps) {
      String instruction = step['html_instructions'];
      directionsWidgets.add(
        ListTile(
          leading: Icon(Icons.directions_walk),
          title: Text(instruction),
        ),
      );
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Yön Tarifi"),
          content: SingleChildScrollView(
            child: Column(
              children: directionsWidgets,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Kapat"),
            ),
          ],
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
        listenFor: Duration(seconds: 10),
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
        title: Text("Voice Navigation"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : LatLng(0, 0),
              zoom: 14.0,
            ),
            onMapCreated: (controller) {
              mapController = controller;
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
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  FloatingActionButton(
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
