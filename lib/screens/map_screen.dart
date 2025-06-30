import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'watch_settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../widgets/widgets.dart'; // Import widgets
import '../utils/responsive_utils.dart'; // Import ResponsiveUtils
import 'dart:math';

const Color kPrimaryCyan = Color(0xFF2EC4B6);
const Color kAccentCoral = Color(0xFFFF6F61);
const Color kSoftBaczkground = Color(0xFFF0FDFC);
const Color kCardBackground = Color(0xFFFFFFFF);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const LatLng _initialPosition = LatLng(32.4617, 35.3006);
  double _currentZoom = 15.0;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Set<Polyline> _polylines = {}; // Add a set for polylines
  final Map<String, List<LatLng>> _childrenLocationHistory = {};
  final int _notificationCount = 0;
  final Map<String, DateTime> _lastAlertTimes = {};
  StreamSubscription? _childrenValueSubscription;
  StreamSubscription? _childrenChildChangedSubscription;
  final Map<String, dynamic> _childrenData = {};
  bool _isAnyChildUnsafe = false;
  double _currentSheetSize = 0.15;
  Timer? _flashTimer;
  bool _showRedBackground = false;
  String? _selectedChildId;
  @override
  void initState() {
    super.initState();
    print('MapScreen initState called.');
    _subscribeToChildrenLocations();
  }

  @override
  void dispose() {
    _childrenValueSubscription?.cancel();
    _childrenChildChangedSubscription?.cancel();
    _flashTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _subscribeToChildrenLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('children');

    print('MapScreen: _subscribeToChildrenLocations called. User: ${user.uid}');

    _childrenValueSubscription?.cancel();
    print('MapScreen: Previous children value subscription cancelled.');

    _childrenValueSubscription = userRef.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          final childrenData = event.snapshot.value as Map<dynamic, dynamic>;
          print('MapScreen: Children value listener triggered.');
          print('MapScreen: Raw snapshot value: ${event.snapshot.value}');

          Set<Marker> newMarkers = {};
          Set<Circle> newCircles = {};
          Set<Polyline> newPolylines = {};

          print('MapScreen: Processing children data.');
          bool anyUnsafe = false;

          childrenData.forEach((childId, data) {
            print('MapScreen: Processing child ID: $childId');
            // Ensure data is a Map<String, dynamic>
            if (data is Map) {
              final childData = Map<String, dynamic>.from(data);
              print('MapScreen: Child raw data: $childData');

              final locationData =
                  childData['location'] as Map<dynamic, dynamic>?;
              final safeZoneData =
                  childData['safeZone'] as Map<dynamic, dynamic>?;

              bool isSafe = true; // Assume safe initially

              double? getLat(Map<dynamic, dynamic>? data) {
                if (data == null) return null;
                return (data['latitude'] as num?)?.toDouble() ??
                    (data['lat'] as num?)?.toDouble();
              }

              double? getLng(Map<dynamic, dynamic>? data) {
                if (data == null) return null;
                return (data['longitude'] as num?)?.toDouble() ??
                    (data['lng'] as num?)?.toDouble();
              }

              if (locationData != null && safeZoneData != null) {
                final currentLat = getLat(locationData);
                final currentLng = getLng(locationData);
                final centerLat = getLat(safeZoneData);
                final centerLng = getLng(safeZoneData);
                final radius = safeZoneData['radius'];

                if (currentLat != null &&
                    currentLng != null &&
                    centerLat != null &&
                    centerLng != null &&
                    radius != null) {
                  final double radiusDouble =
                      (radius is num) ? radius.toDouble() : 0.0;
                  isSafe = _isInSafeZone(
                    currentLat,
                    currentLng,
                    centerLat,
                    centerLng,
                    radiusDouble,
                  );
                  print(
                    'MapScreen: Child $childId isSafe status calculated as: $isSafe',
                  );

                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final childRef = FirebaseDatabase.instance
                        .ref()
                        .child('users')
                        .child(user.uid)
                        .child('children')
                        .child(childId);

                    childRef
                        .update({'safe': isSafe})
                        .then((_) {
                          print(
                            'MapScreen: Safe status updated in Firebase for $childId: $isSafe',
                          );
                        })
                        .catchError((error) {
                          print(
                            'MapScreen: Error updating safe status in Firebase: $error',
                          );
                        });
                  }
                } else {
                  print(
                    'MapScreen: Incomplete location or safeZone data for $childId, defaulting isSafe to true.',
                  );
                }
              } else {
                print(
                  'MapScreen: Missing location or safeZone data for $childId, defaulting isSafe to true.',
                );
              }

              childData['safe'] = isSafe;

              if (!isSafe) {
                anyUnsafe = true;
              }

              if (locationData != null) {
                print(
                  'MapScreen: Location data found for $childId: $locationData',
                );
                final lat = getLat(locationData);
                final lng = getLng(locationData);

                if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
                  print(
                    'MapScreen: Extracted lat: $lat, lng: $lng for $childId',
                  );
                  final position = LatLng(lat, lng);

                  if (!_childrenLocationHistory.containsKey(childId)) {
                    _childrenLocationHistory[childId] = [];
                  }
                  _childrenLocationHistory[childId]!.add(position);
                  if (_childrenLocationHistory[childId]!.length > 20) {
                    _childrenLocationHistory[childId]!.removeAt(0);
                  }
                  print(
                    'MapScreen: Updated location history for $childId: ${_childrenLocationHistory[childId]?.length} points',
                  );

                  final String colorHex =
                      childData['color'] as String? ?? '#2EC4B6';
                  Color childColor = Color(
                    int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000,
                  );

                  final double markerHue = HSLColor.fromColor(childColor).hue;

                  final marker = Marker(
                    markerId: MarkerId(childId),
                    position: position,
                    infoWindow: InfoWindow(
                      title: childData['name'] as String? ?? childId.toString(),
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                    onTap: () {
                      print('MapScreen: Marker for $childId tapped.');
                      setState(() {
                        _selectedChildId = childId;
                      });
                      _sheetController.animateTo(
                        0.15,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  );
                  newMarkers.add(marker);
                  print('MapScreen: Added marker for $childId.');

                  if (safeZoneData != null) {
                    final safeZoneLat = getLat(safeZoneData);
                    final safeZoneLng = getLng(safeZoneData);
                    final radius = safeZoneData['radius'];

                    if (safeZoneLat != null &&
                        safeZoneLng != null &&
                        radius != null) {
                      final double radiusDouble =
                          (radius is num) ? radius.toDouble() : 0.0;
                      newCircles.add(
                        Circle(
                          circleId: CircleId(childId),
                          center: LatLng(safeZoneLat, safeZoneLng),
                          radius: radiusDouble,
                          fillColor: childColor.withOpacity(0.2),
                          strokeColor: childColor,
                          strokeWidth: 2,
                        ),
                      );
                      print('MapScreen: Added safe zone circle for $childId.');
                    }
                  }
                } else {
                  print(
                    'MapScreen: Invalid coordinates for $childId (lat: $lat, lng: $lng)',
                  );
                }
              } else {
                print('MapScreen: No location data for $childId');
              }

              _childrenData[childId.toString()] = childData;
              print(
                'MapScreen: Stored child data for $childId: $_childrenData',
              ); // Debug print
            }
          });

          print('MapScreen: Finished processing children data.');
          print('MapScreen: Calling setState to update map and list...');
          setState(() {
            _markers = newMarkers;
            _circles = newCircles;
            _polylines = newPolylines;
            _isAnyChildUnsafe = anyUnsafe;

            if (_isAnyChildUnsafe) {
              if (_flashTimer == null || !_flashTimer!.isActive) {
                _flashTimer = Timer.periodic(const Duration(seconds: 3), (
                  Timer timer,
                ) {
                  setState(() {
                    _showRedBackground =
                        !_showRedBackground; // Toggle visibility
                  });
                });
                _showRedBackground =
                    true; // Show red immediately when turning unsafe
              }
            } else {
              _flashTimer?.cancel();
              _flashTimer = null;
              _showRedBackground = false;
            }

            if (_isAnyChildUnsafe && _currentSheetSize <= 0.2) {
              print(
                'MapScreen: Unsafe child detected and sheet is minimized. Expanding sheet.',
              ); // Debug print
              _sheetController.animateTo(
                0.4,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }

            print('MapScreen: Total markers: ${_markers.length}');
            print('MapScreen: Total circles: ${_circles.length}');
            print('MapScreen: Total polylines: ${_polylines.length}');
            if (_markers.isNotEmpty) {
              _centerMap(_markers.first.position);
              print('MapScreen: setState called and map centering attempted.');
              print(
                'MapScreen: Centering map to [38;5;246m[48;5;236m${_markers.first.position}[0m with zoom $_currentZoom',
              );
            } else {
              print('MapScreen: setState called but no markers to center on.');
            }
          });
          print('MapScreen: setState finished.'); // Debug print after setState
        } else {
          print(
            'MapScreen: Children value listener triggered, but snapshot does not exist.',
          );
          // If snapshot doesn't exist, clear markers, circles, and polylines
          print(
            'MapScreen: Calling setState to clear map and list...',
          ); // Debug print before setState
          setState(() {
            _markers = {};
            _circles = {};
            _polylines = {};
            print(
              'MapScreen: Markers, circles, and polylines cleared because snapshot does not exist.',
            );
          });
          print('MapScreen: setState finished.'); // Debug print after setState
        }
      },
      onError: (error) {
        print('MapScreen: Children value listener error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveUtils(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'Map',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 24,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          setState(() {
            _currentSheetSize = notification.extent;
            if (_currentSheetSize <= 0.16) {
              _selectedChildId = null;
            }
          });
          return true;
        },
        child: Stack(
          children: [
            Icon(
              Icons.cloud,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
            Icon(
              Icons.cloud,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
            Icon(
              Icons.cloud,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 15,
              ),
              markers: _markers,
              circles: _circles,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _mapController = controller;
                print('MapScreen: GoogleMap created.');
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
              },
            ),
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.4,
              minChildSize: 0.15,
              maxChildSize: 0.5,
              expand: true,
              builder: (
                BuildContext context,
                ScrollController scrollController,
              ) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, -4),
                      ),
                      if (_isAnyChildUnsafe)
                        BoxShadow(
                          color: kAccentCoral.withOpacity(0.6),
                          blurRadius: 20.0,
                          spreadRadius: 8.0,
                          offset: const Offset(0, -6),
                        ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: _isAnyChildUnsafe ? 4.0 : 2.0,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: _childrenData.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Container(
                                    height: 30.0,
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 40.0,
                                      height: 4.0,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(
                                          2.0,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // Adjust index for the rest of the items since index 0 is now the handle
                                final actualIndex = index - 1;
                                final childId = _childrenData.keys.elementAt(
                                  actualIndex,
                                );
                                final childData =
                                    _childrenData[childId]
                                        as Map<dynamic, dynamic>?;

                                if (childData == null) return SizedBox.shrink();

                                final name =
                                    childData['name'] as String? ??
                                    childId.toString();
                                final isSafe =
                                    childData['safe'] as bool? ?? true;
                                final statusText =
                                    isSafe ? 'Safe' : 'Outside Zone';
                                final colorHex =
                                    childData['color'] as String? ?? '#2EC4B6';
                                final childColor = Color(_hexToColor(colorHex));
                                final statusColor =
                                    isSafe
                                        ? Colors.green[700]
                                        : Colors.red[700];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical:
                                        14.0, // Slightly increased vertical padding
                                    horizontal:
                                        20.0, // Increased horizontal padding
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      print(
                                        'MapScreen: Card for $name tapped.',
                                      ); // Debug print

                                      // --- Add map centering logic back here ---
                                      final locationData =
                                          childData['location']
                                              as Map<dynamic, dynamic>?;
                                      if (locationData != null) {
                                        final lat =
                                            (locationData['latitude'] as num?)
                                                ?.toDouble();
                                        final lng =
                                            (locationData['longitude'] as num?)
                                                ?.toDouble();
                                        if (lat != null && lng != null) {
                                          final position = LatLng(lat, lng);
                                          print(
                                            'MapScreen: Attempting to center map on $position from card tap.',
                                          ); // Debug print

                                          // Also get safe zone data to zoom to circle if available
                                          final safeZoneData =
                                              childData['safeZone']
                                                  as Map<dynamic, dynamic>?;
                                          if (safeZoneData != null) {
                                            final centerLat =
                                                (safeZoneData['latitude']
                                                        as num?)
                                                    ?.toDouble();
                                            final centerLng =
                                                (safeZoneData['longitude']
                                                        as num?)
                                                    ?.toDouble();
                                            final radius =
                                                safeZoneData['radius']; // Radius can be int or double from Firebase

                                            if (centerLat != null &&
                                                centerLng != null &&
                                                radius != null) {
                                              final center = LatLng(
                                                centerLat,
                                                centerLng,
                                              );
                                              final double radiusDouble =
                                                  (radius is num)
                                                      ? radius.toDouble()
                                                      : 0.0;

                                              print(
                                                'MapScreen: Attempting to zoom to safe zone for $name from card tap.',
                                              ); // Debug print
                                              _mapController?.animateCamera(
                                                CameraUpdate.newLatLngZoom(
                                                  center,
                                                  _getZoomLevelForRadius(
                                                    radiusDouble,
                                                  ),
                                                ),
                                              ); // Center on safe zone and adjust zoom
                                            } else {
                                              // If safe zone data is incomplete, just center on the child's location
                                              print(
                                                'MapScreen: Incomplete safe zone data for $name, centering on child from card tap.',
                                              ); // Debug print
                                              _centerMap(
                                                position,
                                              ); // Center map on child's location
                                            }
                                          } else {
                                            // If no safe zone data, just center on the child's location
                                            print(
                                              'MapScreen: No safe zone data for $name, centering on child from card tap.',
                                            ); // Debug print
                                            _centerMap(
                                              position,
                                            ); // Center map on child's location
                                          }
                                        }
                                      }
                                      // --- End map centering logic ---

                                      // Update selected child ID
                                      setState(() {
                                        _selectedChildId = childId;
                                      });
                                      // Minimize the draggable sheet
                                      print(
                                        'MapScreen: Attempting to minimize sheet from card tap.',
                                      ); // Debug print
                                      _sheetController.animateTo(
                                        0.15, // Animate to the new minimum size
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ), // Animation duration
                                        curve:
                                            Curves.easeOut, // Animation curve
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            isSafe
                                                ? childColor.withOpacity(
                                                  0.15,
                                                ) // Use child color with opacity if safe
                                                : Colors.red.withOpacity(
                                                  0.15,
                                                ), // Use a red tint if unsafe
                                        borderRadius: BorderRadius.circular(
                                          24.0,
                                        ), // Match WatchCard border radius
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ), // Match WatchCard shadow
                                            blurRadius:
                                                12.0, // Match WatchCard shadow
                                            offset: const Offset(
                                              0,
                                              4,
                                            ), // Match WatchCard shadow
                                          ),
                                        ],
                                        // Add a border if this card is selected
                                        border:
                                            _selectedChildId == childId
                                                ? Border.all(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .primary, // Highlight color
                                                  width: 2.0,
                                                )
                                                : null, // No border if not selected
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical:
                                              14.0, // Slightly increased vertical padding
                                          horizontal:
                                              20.0, // Increased horizontal padding
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  isSafe
                                                      ? childColor.withOpacity(
                                                        0.2,
                                                      ) // Use child color with opacity if safe
                                                      : Colors.red.withOpacity(
                                                        0.2,
                                                      ), // Use red with opacity if unsafe
                                              radius: 24,
                                              child: Icon(
                                                Icons.person, // Person icon
                                                color:
                                                    isSafe
                                                        ? childColor
                                                        : Colors
                                                            .red, // Icon color based on status
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  isSafe
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .red,
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        width: 8,
                                                      ), // Space between dot and name
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          style: GoogleFonts.nunito(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ), // Removed overflow from style
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis, // Add ellipsis for overflow
                                                        ),
                                                      ), // Wrap with Expanded
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 6,
                                                  ), // Increased space after name
                                                  Row(
                                                    // Row for Status Text and Icon
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          statusText,
                                                          style: TextStyle(
                                                            color: statusColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis, // Add ellipsis for overflow
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        isSafe
                                                            ? Icons
                                                                .check_circle_outline
                                                            : Icons
                                                                .warning_amber_outlined, // Warning icon for unsafe
                                                        color: statusColor,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                                  if (childData['lastSeen'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top:
                                                                4.0, // Consistent space above last seen
                                                          ),
                                                      child: Text(
                                                        'Last seen: ${_formatRelativeTime(childData['lastSeen'])}',
                                                        style: GoogleFonts.nunito(
                                                          fontSize:
                                                              13, // Slightly larger font for last seen
                                                          color: Theme.of(
                                                                context,
                                                              )
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(
                                                                0.7,
                                                              ), // Slightly darker grey
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // ADDED: Button to center map on child location
                                            IconButton(
                                              icon: Icon(
                                                Icons.location_on,
                                                color:
                                                    childColor, // Use the child's assigned color
                                                size: 28,
                                              ),
                                              onPressed: () {
                                                print(
                                                  'MapScreen: Location button tapped for $name.',
                                                ); // Debug print
                                                final locationData =
                                                    childData['location']
                                                        as Map<
                                                          dynamic,
                                                          dynamic
                                                        >?;
                                                if (locationData != null) {
                                                  final lat =
                                                      (locationData['latitude']
                                                              as num?)
                                                          ?.toDouble();
                                                  final lng =
                                                      (locationData['longitude']
                                                              as num?)
                                                          ?.toDouble();
                                                  if (lat != null &&
                                                      lng != null) {
                                                    final position = LatLng(
                                                      lat,
                                                      lng,
                                                    );
                                                    // Also get safe zone data to zoom to circle
                                                    final safeZoneData =
                                                        childData['safeZone']
                                                            as Map<
                                                              dynamic,
                                                              dynamic
                                                            >?;
                                                    if (safeZoneData != null) {
                                                      final centerLat =
                                                          (safeZoneData['latitude']
                                                                  as num?)
                                                              ?.toDouble();
                                                      final centerLng =
                                                          (safeZoneData['longitude']
                                                                  as num?)
                                                              ?.toDouble();
                                                      final radius =
                                                          safeZoneData['radius']; // Radius can be int or double

                                                      if (centerLat != null &&
                                                          centerLng != null &&
                                                          radius != null) {
                                                        final center = LatLng(
                                                          centerLat,
                                                          centerLng,
                                                        );
                                                        final double
                                                        radiusDouble =
                                                            (radius is num)
                                                                ? radius
                                                                    .toDouble()
                                                                : 0.0;

                                                        // Instead of centering on the child, center on the safe zone and adjust zoom
                                                        print(
                                                          'MapScreen: Attempting to zoom to safe zone for $name via button.',
                                                        ); // Debug print
                                                        _mapController?.animateCamera(
                                                          CameraUpdate.newLatLngZoom(
                                                            center,
                                                            _getZoomLevelForRadius(
                                                              radiusDouble,
                                                            ),
                                                          ),
                                                        ); // Center on safe zone and adjust zoom
                                                      } else {
                                                        // If safe zone data is incomplete, just center on the child's location
                                                        print(
                                                          'MapScreen: Incomplete safe zone data for $name, centering on child via button.',
                                                        ); // Debug print
                                                        _centerMap(
                                                          position,
                                                        ); // Center map on child's location
                                                      }
                                                    } else {
                                                      // If no safe zone data, just center on the child's location
                                                      print(
                                                        'MapScreen: No safe zone data for $name, centering on child via button.',
                                                      ); // Debug print
                                                      _centerMap(
                                                        position,
                                                      ); // Center map on child's location
                                                    }
                                                  }
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.settings,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                                size: 24,
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => WatchSettingsScreen(
                                                          watchId: childId,
                                                          getWatchData: (id) {
                                                            final data =
                                                                _childrenData[id];
                                                            if (data
                                                                is Map<
                                                                  dynamic,
                                                                  dynamic
                                                                >) {
                                                              return Map<
                                                                String,
                                                                dynamic
                                                              >.fromEntries(
                                                                data.entries.map(
                                                                  (
                                                                    entry,
                                                                  ) => MapEntry(
                                                                    entry.key
                                                                        .toString(),
                                                                    entry.value
                                                                            is Map
                                                                        ? Map<
                                                                          String,
                                                                          dynamic
                                                                        >.fromEntries(
                                                                          (entry.value
                                                                                  as Map<
                                                                                    dynamic,
                                                                                    dynamic
                                                                                  >)
                                                                              .entries
                                                                              .map(
                                                                                (
                                                                                  nestedEntry,
                                                                                ) => MapEntry(
                                                                                  nestedEntry.key.toString(),
                                                                                  nestedEntry.value,
                                                                                ),
                                                                              ),
                                                                        )
                                                                        : entry
                                                                            .value,
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            return {};
                                                          },
                                                          onRemove: () {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          },
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.parse(hex, radix: 16);
  }

  Future<void> _centerMap(LatLng location) async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(location, _currentZoom),
    );
    print('MapScreen: Centering map to $location with zoom $_currentZoom');
  }

  void _updateMarkersAndCircles(Map<String, dynamic> childrenData) {
    // Clear existing markers and circles
    _markers.clear(); // Explicitly clear the sets
    _circles.clear();

    childrenData.forEach((childId, data) {
      // ... existing code ...
    });
  }

  // Helper function to format time into a relative string (e.g., '5 mins ago')
  String _formatRelativeTime(dynamic lastSeenData) {
    if (lastSeenData == null) return 'Never';

    // Attempt to parse as a timestamp (milliseconds since epoch)
    int? timestampMillis;
    if (lastSeenData is int) {
      timestampMillis = lastSeenData;
    } else if (lastSeenData is String) {
      try {
        timestampMillis = int.parse(lastSeenData);
      } catch (e) {
        // If parsing as int fails, maybe it's already a formatted string like 'Now' or 'Today'
        return lastSeenData; // Return the raw string if it's not a parsable timestamp
      }
    } else {
      // Handle other potential data types gracefully
      return 'Invalid data format';
    }

    if (timestampMillis == null)
      return 'Invalid time'; // Should be caught by parsing logic, but as a fallback

    final lastSeenTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final now = DateTime.now();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} mins ago';
    if (difference.inDays < 1) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${lastSeenTime.toLocal().toString().split(' ')[0]}'; // Just show the date (YYYY-MM-DD)
  }

  double _getZoomLevelForRadius(double radius) {
    if (radius < 50) return 20.0;
    if (radius < 100) return 19.0;
    if (radius < 200) return 18.0;
    if (radius < 500) return 17.0;
    if (radius < 1000) return 16.0;
    return 15.0;
  }

  bool _isInSafeZone(
    double currentLat,
    double currentLng,
    double zoneLat,
    double zoneLng,
    double zoneRadius,
  ) {
    const earthRadius = 6371000;
    final dLat = (currentLat - zoneLat).abs() * (pi / 180);
    final dLng = (currentLng - zoneLng).abs() * (pi / 180);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(zoneLat * (pi / 180)) *
            cos(currentLat * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance <= zoneRadius;
  }
}
