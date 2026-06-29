import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const KonumTakipApp());
}

class KonumTakipApp extends StatelessWidget {
  const KonumTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Konum Takip',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HaritaEkran(),
    );
  }
}

class HaritaEkran extends StatefulWidget {
  const HaritaEkran({super.key});

  @override
  State<HaritaEkran> createState() => _HaritaEkranState();
}

class _HaritaEkranState extends State<HaritaEkran> {
  // Varsayilan harita baslangic noktasi
  final LatLng _baslangicMerkezi = const LatLng(38.25, 30.90);
  bool _takipEdiliyor = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1 OpenStreetMap
          FlutterMap(
            options: MapOptions(
              initialCenter: _baslangicMerkezi,
              initialZoom: 11.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rumata.konum_takip_app',
                tileProvider: NetworkTileProvider(),
              ),
            ],
          ),

          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_takipEdiliyor)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _takipEdiliyor = true;
                      });

                      // TODO: A noktasi takibi ve takibi baslatma buraya eklenecek
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('A Noktasi (Basla)'),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _takipEdiliyor = false;
                      });
                      // TODO: B Noktasi kaydi ve rotasi bitirme buraya gelecek
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('B Noktasi (Bitir)'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Button text support useful support widget

class SizeBoxedText extends StatelessWidget {
  final String text;
  const SizeBoxedText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
