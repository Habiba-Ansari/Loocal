import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMapScreen extends StatefulWidget {
  const PrivateMapScreen({super.key});

  @override
  State<PrivateMapScreen> createState() => _PrivateMapScreenState();
}

class _PrivateMapScreenState extends State<PrivateMapScreen> {
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  bool _isMarkingMode = false;
  Set<Marker> _allMarkers = {};
  Set<Marker> _visibleMarkers = {};
  Map<String, List<String>> _markerNotes = {};
  Map<String, String> _markerTitles = {};
  final TextEditingController _searchController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String uid;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    User? user = _auth.currentUser;
    if (user == null) {
      user = (await _auth.signInAnonymously()).user;
    }
    uid = user!.uid;
    await _determinePosition();
    await _loadMarkersFromFirestore();
  }

  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await _firestore.collection('users').doc(uid).collection('markers').get();
    _allMarkers.clear();
    _markerTitles.clear();
    _markerNotes.clear();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final id = doc.id;
      final title = data['title'] ?? '';
      final notes = List<String>.from(data['notes'] ?? []);

      _markerTitles[id] = title;
      _markerNotes[id] = notes;

      final marker = Marker(
        markerId: MarkerId(id),
        position: LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()),
        onTap: () => _openNotesDialog(id),
      );
      _allMarkers.add(marker);
    }

    setState(() {
      _visibleMarkers = _allMarkers;
    });
  }

  Future<void> _saveMarkerToFirestore(String id, LatLng pos) async {
    await _firestore.collection('users').doc(uid).collection('markers').doc(id).set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'title': _markerTitles[id] ?? '',
      'notes': _markerNotes[id] ?? [],
    }, SetOptions(merge: true));
  }

  Future<void> _deleteMarkerFromFirestore(String id) async {
    await _firestore.collection('users').doc(uid).collection('markers').doc(id).delete();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
  }

  void _onMapTap(LatLng position) {
    if (!_isMarkingMode) return;
    String inputTitle = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Name this place"),
        content: TextField(
          decoration: const InputDecoration(hintText: "e.g. My Spot"),
          onChanged: (val) => inputTitle = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              _markerTitles[id] = inputTitle;
              _markerNotes[id] = [];

              final marker = Marker(
                markerId: MarkerId(id),
                position: position,
                onTap: () => _openNotesDialog(id),
              );

              setState(() {
                _allMarkers.add(marker);
                _visibleMarkers = _allMarkers;
                _isMarkingMode = false;
              });

              await _saveMarkerToFirestore(id, position);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _deleteMarker(String markerId) async {
    setState(() {
      _allMarkers.removeWhere((m) => m.markerId.value == markerId);
      _visibleMarkers.removeWhere((m) => m.markerId.value == markerId);
      _markerTitles.remove(markerId);
      _markerNotes.remove(markerId);
    });

    await _deleteMarkerFromFirestore(markerId);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Marker deleted")),
    );
  }

  void _openNotesDialog(String markerId) {
    final notes = _markerNotes[markerId] ?? [];
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_markerTitles[markerId] ?? "Notes"),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteMarker(markerId),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...notes.map((note) => ListTile(title: Text(note))),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "Add a note..."),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                _markerNotes[markerId]?.add(controller.text.trim());
                await _saveMarkerToFirestore(
                  markerId,
                  _allMarkers.firstWhere((m) => m.markerId.value == markerId).position,
                );
                Navigator.pop(context);
                _openNotesDialog(markerId);
              }
            },
            child: const Text("Add Note"),
          ),
        ],
      ),
    );
  }

  void _searchMarkers() {
    String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _visibleMarkers = _allMarkers);
      return;
    }
    final filtered = _allMarkers.where((marker) {
      final id = marker.markerId.value;
      final title = _markerTitles[id]?.toLowerCase() ?? '';
      final notes = (_markerNotes[id] ?? []).join(' ').toLowerCase();
      return title.contains(query) || notes.contains(query);
    }).toSet();

    setState(() {
      _visibleMarkers = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Loocal - Private Map")),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14),
                  myLocationEnabled: true,
                  markers: _visibleMarkers,
                  onTap: _onMapTap,
                ),
                if (!_isMarkingMode)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "Search markers or notes...",
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _searchMarkers(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchMarkers,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _isMarkingMode = !_isMarkingMode),
        backgroundColor: Colors.blue,
        child: Icon(_isMarkingMode ? Icons.close : Icons.note_add),
        tooltip: _isMarkingMode ? "Cancel" : "Add Note Marker",
      ),
    );
  }
}
