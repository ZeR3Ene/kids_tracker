import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:another_flushbar/flushbar.dart';
import 'dart:async';

class WatchSettingsScreen extends StatefulWidget {
  final String? watchId;
  final Map<String, dynamic> Function(String) getWatchData;
  final VoidCallback onRemove;

  const WatchSettingsScreen({
    super.key,
    this.watchId,
    required this.getWatchData,
    required this.onRemove,
  });

  @override
  State<WatchSettingsScreen> createState() => _WatchSettingsScreenState();
}

class _WatchSettingsScreenState extends State<WatchSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _color = '#2EC4B6';
  Map? _safeZone;
  bool _loading = true;
  String? _error;
  Timer? sosTimer;

  String get watchId => widget.watchId ?? 'child_1';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    print('WatchSettingsScreen disposed');
    sosTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not logged in.';
          _loading = false;
        });
        return;
      }

      final watchRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/children/${watchId}',
      );
      final snapshot = await watchRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> watchData = Map.from(data);

        // Get location data
        final location = watchData['location'] as Map<dynamic, dynamic>?;

        // Initialize safe zone with watch's location if available
        if (location != null &&
            location['lat'] != null &&
            location['lng'] != null) {
          _safeZone = {
            'lat': location['lat'] as double,
            'lng': location['lng'] as double,
            'radius': 100.0, // Default radius of 100 meters
            'color': _color,
          };
        } else {
          // If no location, use existing safe zone or default to center
          _safeZone =
              watchData['safeZone'] ??
              {
                'lat': 32.4617, // Default center latitude
                'lng': 35.3006, // Default center longitude
                'radius': 100.0,
                'color': _color,
              };
        }

        setState(() {
          _nameController.text = watchData['name'] ?? '';
          _color = watchData['color'] ?? '#2EC4B6';
        });
      } else {
        setState(() {
          _error = 'Watch not found or no data.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading watch data: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not logged in.';
          _loading = false;
        });
        return;
      }

      final updates = {
        'name': _nameController.text.trim(),
        'color': _color,
        'safeZone': _safeZone,
        'safeZoneColor': _safeZone?['color'] ?? _color,
      };

      // If we have a location, update it in the updates map
      final location = {
        'lat': _safeZone?['lat'] as double?,
        'lng': _safeZone?['lng'] as double?,
      };
      if (location['lat'] != null && location['lng'] != null) {
        updates['location'] = location;
      }

      final watchRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/children/${watchId}',
      );

      await watchRef.update(updates);

      if (mounted) {
        setState(() {
          _loading = false;
        });
        Navigator.pop(context, updates);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error saving watch data: $e';
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.fromEntries(
        data.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            entry.value is Map ? _convertToMap(entry.value) : entry.value,
          ),
        ),
      );
    }
    return {};
  }

  Future<void> _removeWatch() async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Watch'),
            content: const Text('Are you sure you want to remove this watch?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted && context.mounted) {
            _showTopNotification('User not logged in.', color: Colors.red);
          }
          return;
        }

        final watchRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/children/${watchId}',
        );
        await watchRef.remove();

        if (mounted && context.mounted) {
          Navigator.pop(context, true);
          widget.onRemove();
        }
      } catch (e) {
        if (mounted && context.mounted) {
          Navigator.pop(context, {'error': 'Error removing watch: $e'});
        }
      }
    }
  }

  void _pickColor() async {
    final colors = [
      {'hex': '#2EC4B6', 'name': 'Cyan'},
      {'hex': '#FF6F61', 'name': 'Coral'},
      {'hex': '#FFD166', 'name': 'Yellow'},
      {'hex': '#3A86FF', 'name': 'Blue'},
      {'hex': '#8338EC', 'name': 'Purple'},
    ];
    final picked = await showDialog<String>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Pick a color'),
            children:
                colors.map((c) {
                  return SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, c['hex']),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(_hexToColor(c['hex']!)),
                          radius: 12,
                        ),
                        const SizedBox(width: 12),
                        Text(c['name']!),
                      ],
                    ),
                  );
                }).toList(),
          ),
    );
    if (picked != null) {
      setState(() => _color = picked);
    }
  }

  void _pickSafeZone() async {
    final zone = await Navigator.push<Map?>(
      context,
      MaterialPageRoute(
        builder: (context) => SafeZonePickerScreen(initial: _safeZone),
      ),
    );
    if (zone != null) setState(() => _safeZone = zone);
  }

  int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.parse(hex, radix: 16);
  }

  void _showTopNotification(String message, {Color? color}) {
    Flushbar(
      message: message,
      backgroundColor: color ?? Colors.black87,
      duration: const Duration(seconds: 2),
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(Icons.info, color: Colors.white),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
        title: const Text(
          'Watch Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 6,
                    color: theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Edit Watch',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Watch Name',
                                filled: true,
                                fillColor: theme.cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                              ),
                              style: const TextStyle(fontSize: 12),
                              validator:
                                  (v) =>
                                      v == null || v.isEmpty
                                          ? 'Please enter a name'
                                          : null,
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  const Text(
                                    'Color:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: Color(_hexToColor(_color)),
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: _pickColor,
                                    child: const Text(
                                      'Pick Color',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Text(
                                    'Safe Zone: ',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _safeZone != null
                                      ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Set',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      )
                                      : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.cancel,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Unset',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _pickSafeZone,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Pick on Map',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6F61),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _loading ? null : _save,
                                child:
                                    _loading
                                        ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Text(
                                          'Save',
                                          style: TextStyle(fontSize: 12),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _removeWatch,
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              label: const Text(
                                'Remove This Watch',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}

class SafeZonePickerScreen extends StatefulWidget {
  final Map? initial;
  const SafeZonePickerScreen({this.initial, super.key});

  @override
  State<SafeZonePickerScreen> createState() => _SafeZonePickerScreenState();
}

class _SafeZonePickerScreenState extends State<SafeZonePickerScreen> {
  LatLng? _center;
  double _radius = 100;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _center = LatLng(
        (widget.initial!['lat'] ?? 0).toDouble(),
        (widget.initial!['lng'] ?? 0).toDouble(),
      );
      _radius = (widget.initial!['radius'] ?? 100).toDouble();
    } else {
      _center = const LatLng(37.42796133580664, -122.085749655962);
    }
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    _mapStyle = await rootBundle.loadString('assets/map_style_kid.json');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Safe Zone')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center!, zoom: 15),
            circles: {
              Circle(
                circleId: const CircleId('zone'),
                center: _center!,
                radius: _radius,
                fillColor: Colors.green.withOpacity(0.2),
                strokeColor: Colors.green,
                strokeWidth: 2,
              ),
            },
            onTap: (pos) => setState(() => _center = pos),
            onMapCreated: (controller) {
              if (_mapStyle != null) {
                controller.setMapStyle(_mapStyle);
              }
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              children: [
                Text(
                  'Radius: ${_radius.toInt()} meters',
                  style: theme.textTheme.bodyLarge,
                ),
                Slider(
                  min: 1,
                  max: 1000,
                  value: _radius,
                  label: '${_radius.toInt()}m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'lat': _center!.latitude,
                      'lng': _center!.longitude,
                      'radius': _radius,
                    });
                  },
                  child: const Text('Set Safe Zone'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
