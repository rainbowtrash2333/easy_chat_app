import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
// todo：修改为传入经纬度，显示marker
class Map extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

class _MapState extends State<Map> {
  GoogleMapController _controller ;

  static const LatLng _center = const LatLng(39.913818, 116.363625);

  final Set<Marker> _markers = {};

  LatLng _lastMapPosition = _center;

  MapType _currentMapType = MapType.normal;

  Position _currentPosition;

  _getCurrentLocation() {
    final Geolocator geolocator = Geolocator()
      ..forceAndroidLocationManager;

    geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((Position position) {
      setState(() {
        _currentPosition = position;
//        print("position:${position.toString()} ");
      });
    }).catchError((e) {
      print(e);
    });
  }

  LatLng _userPostion=LatLng(24.8275832, 102.8522499);

  void _onAddMarkerButtonPressed() {
    _getCurrentLocation();
    _controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target: _userPostion, zoom: 10.0),
      ),
    );

    if (_currentPosition != null) {
      _userPostion = LatLng(_currentPosition.latitude, _currentPosition.longitude);
      print("LAT: ${_currentPosition.latitude}, LNG: ${_currentPosition.longitude}");
    }

    setState(() {
      _markers.clear();
      _markers.add(Marker(
        // This marker id can be anything that uniquely identifies each marker.
        markerId: MarkerId(_userPostion.toString()),
        position: _userPostion,
        infoWindow: InfoWindow(
          title: 'your Position',
          snippet: 'your location',
        ),
        icon: BitmapDescriptor.defaultMarker,
      ));
    });
  }

  void _onCameraMove(CameraPosition position) {
    _lastMapPosition = position.target;
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('My Little Map'),
          backgroundColor: Colors.blue[700],
        ),
        body: Stack(
          children: <Widget>[
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 11.0,
              ),
              mapType: _currentMapType,
              markers: _markers,
              onCameraMove: _onCameraMove,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.bottomRight,
                child:FloatingActionButton(
                  onPressed: _onAddMarkerButtonPressed,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add_location, size: 36.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
