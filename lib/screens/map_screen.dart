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

// Import ui for Image
// Import theme colors

const Color kPrimaryCyan = Color(0xFF2EC4B6);
const Color kAccentCoral = Color(0xFFFF6F61);
const Color kSoftBackground = Color(0xFFF0FDFC);
const Color kCardBackground = Color(0xFFFFFFFF); // Import kCardBackground

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
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Set<Polyline> _polylines = {}; // Add a set for polylines
  final Map<String, List<LatLng>> _childrenLocationHistory =
      {}; // Map to store location history for each child
  final int _notificationCount = 0;
  final Map<String, DateTime> _lastAlertTimes = {};
  StreamSubscription? _childrenValueSubscription;
  StreamSubscription? _childrenChildChangedSubscription;
  final Map<String, dynamic> _childrenData = {};
  bool _isAnyChildUnsafe =
      false; // Add state variable to track if any child is unsafe
  double _currentSheetSize =
      0.15; // State variable to store current sheet size, initialize with minChildSize
  Timer? _flashTimer; // Timer for the flashing background
  bool _showRedBackground =
      false; // State variable to control red background visibility
  String?
  _selectedChildId; // State variable to hold the ID of the selected child

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
    _flashTimer?.cancel(); // Cancel timer in dispose
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

    // Cancel previous subscription if it exists
    _childrenValueSubscription?.cancel();
    print('MapScreen: Previous children value subscription cancelled.');

    _childrenValueSubscription = userRef.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          final childrenData = event.snapshot.value as Map<dynamic, dynamic>;
          print('MapScreen: Children value listener triggered.');
          print('MapScreen: Raw snapshot value: ${event.snapshot.value}');

          // Process data and create new sets of markers, circles, and polylines
          Set<Marker> newMarkers = {}; // Create new sets
          Set<Circle> newCircles = {};
          Set<Polyline> newPolylines = {}; // Create a new set for polylines

          print('MapScreen: Processing children data.');
          bool anyUnsafe =
              false; // Temporarily track if any child is unsafe in this update

          childrenData.forEach((childId, data) {
            print('MapScreen: Processing child ID: $childId');
            // Ensure data is a Map<String, dynamic>
            if (data is Map) {
              final childData = Map<String, dynamic>.from(data);
              print('MapScreen: Child raw data: $childData');

              // Determine the safe status for the child
              // Read the location and safe zone data
              final locationData =
                  childData['location'] as Map<dynamic, dynamic>?;
              final safeZoneData =
                  childData['safeZone'] as Map<dynamic, dynamic>?;

              bool isSafe = true; // Assume safe initially

              if (locationData != null && safeZoneData != null) {
                final currentLat = locationData['lat'] as double?;
                final currentLng = locationData['lng'] as double?;
                final centerLat = safeZoneData['lat'] as double?;
                final centerLng = safeZoneData['lng'] as double?;
                final radius =
                    safeZoneData['radius']; // Radius can be int or double

                if (currentLat != null &&
                    currentLng != null &&
                    centerLat != null &&
                    centerLng != null &&
                    radius != null) {
                  final double radiusDouble =
                      (radius is num) ? radius.toDouble() : 0.0;
                  // Calculate if the child is in the safe zone
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

                  // Save the safe status to Firebase
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

              // Update the childData map with the calculated isSafe status
              childData['safe'] = isSafe;

              if (!isSafe) {
                anyUnsafe = true; // Set flag if child is unsafe
              }

              // Process location for markers and update history
              if (locationData != null) {
                print(
                  'MapScreen: Location data found for $childId: $locationData',
                );
                final lat = locationData['lat'] as double?;
                final lng = locationData['lng'] as double?;

                if (lat != null && lng != null) {
                  print(
                    'MapScreen: Extracted lat: $lat, lng: $lng for $childId',
                  );
                  final position = LatLng(lat, lng);

                  // Update location history
                  if (!_childrenLocationHistory.containsKey(childId)) {
                    _childrenLocationHistory[childId] = [];
                  }
                  _childrenLocationHistory[childId]!.add(position);
                  // Limit history size (e.g., last 20 points)
                  if (_childrenLocationHistory[childId]!.length > 20) {
                    _childrenLocationHistory[childId]!.removeAt(0);
                  }
                  print(
                    'MapScreen: Updated location history for $childId: ${_childrenLocationHistory[childId]?.length} points',
                  ); // Debug print

                  // Get child's color from data and convert to Color object
                  final String colorHex =
                      childData['color'] as String? ??
                      '#2EC4B6'; // Default color
                  Color childColor = Color(
                    int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000,
                  ); // Add alpha

                  // Calculate hue from child's color for the default marker
                  final double markerHue =
                      HSLColor.fromColor(
                        childColor,
                      ).hue; // Always use child's color hue for the base pin color

                  final marker = Marker(
                    markerId: MarkerId(childId),
                    position: position,
                    infoWindow: InfoWindow(
                      title: childData['name'] as String? ?? childId.toString(),
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      markerHue,
                    ), // Use hue derived from child's color
                    onTap: () {
                      // Add onTap callback
                      print('MapScreen: Marker for $childId tapped.');
                      setState(() {
                        _selectedChildId = childId;
                      });
                      // Minimize the draggable sheet when marker is tapped
                      _sheetController.animateTo(
                        0.15, // Animate to the new minimum size
                        duration: const Duration(
                          milliseconds: 300,
                        ), // Animation duration
                        curve: Curves.easeOut, // Animation curve
                      );
                    },
                  );
                  newMarkers.add(marker); // Add to the new set
                  print('MapScreen: Added marker for $childId.');

                  // Create polyline from history
                  if (_childrenLocationHistory[childId]!.length > 1) {
                    newPolylines.add(
                      Polyline(
                        polylineId: PolylineId(childId.toString()),
                        points: _childrenLocationHistory[childId]!,
                        color: childColor, // Use child's color for the trail
                        width: 4, // Adjust width as needed
                        jointType: JointType.round,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                      ),
                    );
                    print(
                      'MapScreen: Added polyline for $childId with ${_childrenLocationHistory[childId]?.length} points.',
                    ); // Debug print
                  }
                }
              }

              // Process safe zone for circles
              if (safeZoneData != null) {
                print(
                  'MapScreen: SafeZone data found for $childId: $safeZoneData',
                );
                final centerLat = safeZoneData['lat'] as double?;
                final centerLng = safeZoneData['lng'] as double?;
                final radius =
                    safeZoneData['radius']; // Radius can be int or double from Firebase

                if (centerLat != null && centerLng != null && radius != null) {
                  final center = LatLng(centerLat, centerLng);
                  // Ensure radius is a double
                  final double radiusDouble =
                      (radius is num) ? radius.toDouble() : 0.0;
                  print(
                    'MapScreen: Extracted radius: $radiusDouble for $childId',
                  );

                  // Determine circle color (can use the child's assigned color or a fixed color)
                  final String colorHex =
                      // Use safeZoneColor if available, otherwise fall back to child's color
                      childData['safeZoneColor'] as String? ??
                      childData['color'] as String? ??
                      '#2EC4B6'; // Default color
                  Color circleColor = Color(
                    int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000,
                  ); // Default to 100% opacity
                  // Apply a semi-transparent color for the circle
                  circleColor = circleColor.withValues(alpha: 0.3);

                  // Determine stroke color: Red if unsafe, otherwise a slightly more opaque version of the child's color
                  final strokeColor =
                      !isSafe
                          ? Colors.red.withOpacity(
                            0.7,
                          ) // Red stroke for unsafe status
                          : circleColor.withValues(
                            alpha: 0.7,
                          ); // Slightly more opaque stroke of child's color

                  final circle = Circle(
                    circleId: CircleId(childId),
                    center: center,
                    radius: radiusDouble, // Use the double radius
                    fillColor: circleColor, // Semi-transparent fill
                    strokeColor: strokeColor,
                    strokeWidth: 2,
                  );
                  newCircles.add(circle); // Add to the new set
                  print('MapScreen: Added circle for $childId.');
                }
              }

              // Store child data for the bottom panel
              // Update the main state map here, as it's used by the list view
              _childrenData[childId.toString()] = childData;
              print(
                'MapScreen: Stored child data for $childId: $_childrenData',
              ); // Debug print
            }
          });

          print('MapScreen: Finished processing children data.');
          // Update the state with the new sets of markers, circles, and polylines and overall unsafe status
          print(
            'MapScreen: Calling setState to update map and list...',
          ); // Debug print before setState
          setState(() {
            _markers = newMarkers; // Assign the new sets
            _circles = newCircles;
            _polylines = newPolylines; // Assign the new polyline set
            _isAnyChildUnsafe = anyUnsafe; // Update overall unsafe status

            // Handle flashing background timer based on overall unsafe status
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
              _showRedBackground =
                  false; // Ensure background is not red when safe
            }

            // If any child is unsafe and the sheet is minimized, expand it
            if (_isAnyChildUnsafe && _currentSheetSize <= 0.2) {
              // Check if sheet is close to minimized
              print(
                'MapScreen: Unsafe child detected and sheet is minimized. Expanding sheet.',
              ); // Debug print
              _sheetController.animateTo(
                0.4, // Animate to the initial child size
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }

            print('MapScreen: Total markers: ${_markers.length}');
            print('MapScreen: Total circles: ${_circles.length}');
            print('MapScreen: Total polylines: ${_polylines.length}');
            // Attempt to center map after data is loaded and processed
            if (_markers.isNotEmpty) {
              _centerMap(_markers.first.position);
              print('MapScreen: setState called and map centering attempted.');
              print('MapScreen: Centering map to ${_markers.first.position}');
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

  // We can remove the separate onChildChanged listener since onValue handles updates
  // void updateNotificationCount(int count) { ... }

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
            // Clear selected child when the sheet is minimized
            if (_currentSheetSize <= 0.16) {
              // Using a threshold slightly above minChildSize (0.15)
              _selectedChildId = null;
            }
          });
          return true; // Return true to stop the notification from bubbling further
        },
        child: Stack(
          children: [
            // --- Background Cloud Icons ---
            // These will be positioned relative to the main Stack (the screen)
            // Background Cloud Icons (Removed fixed positioning for responsiveness)
            Icon(
              Icons.cloud,
              color: Theme.of(
                context,
              ).colorScheme.surface.withOpacity(0.5), // Use opacity directly
              // size: 250, // Removed fixed size
            ),
            Icon(
              Icons.cloud,
              color: Theme.of(
                context,
              ).colorScheme.surface.withOpacity(0.5), // Use opacity directly
              // size: 280, // Removed fixed size
            ),
            Icon(
              Icons.cloud,
              color: Theme.of(
                context,
              ).colorScheme.surface.withOpacity(0.5), // Use opacity directly
              // size: 230, // Removed fixed size
            ),
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 15,
              ),
              markers: _markers,
              circles: _circles,
              polylines: _polylines, // Add polylines to the map
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _mapController = controller;
                print('MapScreen: GoogleMap created.');
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
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
                    color:
                        Theme.of(context)
                            .colorScheme
                            .surface, // Use white for the sheet background
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20.0),
                    ), // Rounded top corners
                    boxShadow: [
                      // Subtle general shadow
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, -4),
                      ),
                      // Conditional glowing shadow when unsafe
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
                        color:
                            Theme.of(context)
                                .colorScheme
                                .primary, // Add a top border using kPrimaryCyan
                        width:
                            _isAnyChildUnsafe
                                ? 4.0
                                : 2.0, // Thicker border when unsafe
                      ),
                    ),
                  ),
                  child: Stack(
                    // Use a Stack to layer background clouds and foreground content
                    children: [
                      // --- Foreground Content (Handle and ListView) ---
                      Column(
                        // Keep Column to layout the handle and the list vertically
                        children: [
                          // Drag handle area (removed cloud icons from here)
                          Expanded(
                            // Wrap ListView with Expanded
                            child: ListView.builder(
                              controller: scrollController,
                              // ADDED: Add 1 to itemCount to account for the handle
                              itemCount: _childrenData.length + 1,
                              itemBuilder: (context, index) {
                                // ADDED: Add the drag handle as the first item in the ListView
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
                                            locationData['lat'] as double?;
                                        final lng =
                                            locationData['lng'] as double?;
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
                                                safeZoneData['lat'] as double?;
                                            final centerLng =
                                                safeZoneData['lng'] as double?;
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
                                                      locationData['lat']
                                                          as double?;
                                                  final lng =
                                                      locationData['lng']
                                                          as double?;
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
                                                          safeZoneData['lat']
                                                              as double?;
                                                      final centerLng =
                                                          safeZoneData['lng']
                                                              as double?;
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
    controller.animateCamera(CameraUpdate.newLatLngZoom(location, 15.0));
    print('MapScreen: Centering map to $location');
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
    // For times older than a week, you might want to show the date
    return '${lastSeenTime.toLocal().toString().split(' ')[0]}'; // Just show the date (YYYY-MM-DD)
  }

  // Helper function to estimate a zoom level for a given radius (simplified)
  // This is a rough estimation and may need calibration based on map projection and view size.
  double _getZoomLevelForRadius(double radius) {
    // Values are approximate; further increased zoom levels for a tighter view
    if (radius < 50) return 20.0; // Increased from 19.0
    if (radius < 100) return 19.0; // Increased from 18.0
    if (radius < 200) return 18.0; // Increased from 17.0
    if (radius < 500) return 17.0; // Increased from 16.0
    if (radius < 1000) return 16.0; // Increased from 15.0
    return 15.0; // Default for larger radii, increased from 14.0
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
