import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class UserPosition {
  final double latitude;
  final double longitude;

  UserPosition({@required this.latitude, @required this.longitude});

  UserPosition.fromJson(Map<String, dynamic> json)
      : latitude = json['latitude'],
        longitude = json['longitude'];

  Map<String, dynamic> toJson() =>
      {
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  String toString() {
    return "latitude: ${this.latitude}\t longitude: ${this.longitude}";
  }
}

class MapPage extends StatefulWidget {
  final UserPosition position;

  MapPage({@required this.position});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController _controller;
  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }
//  LatLng _center = const LatLng(widget.position.latitude, widget.position.latitude);
  @override
  Widget build(BuildContext context) {
    final LatLng _position =  LatLng(widget.position.latitude, widget.position.longitude);
    print(_position.toString());
    LatLng _lastMapPosition = _position;
    final Set<Marker> _markers ={};
    Marker _maker = Marker(
      // This marker id can be anything that uniquely identifies each marker.
      markerId: MarkerId(_position.toString()),
      position: _position,
      infoWindow: InfoWindow(
        title: 'your Position',
        snippet: 'your location',
      ),
      icon: BitmapDescriptor.defaultMarker,
    );
    _markers.add(_maker);

    void _onCameraMove(CameraPosition position) {
      _lastMapPosition = position.target;
    }
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('位置信息'),
          backgroundColor: Colors.blue[700],
        ),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _position,
            zoom: 15.0,
          ),
          mapType: MapType.normal,
          markers: _markers,
          onCameraMove: _onCameraMove,
        ),
      ),
    );
  }
}
