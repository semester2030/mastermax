import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/map_state.dart';
import '../models/map_marker.dart';
import '../../../core/config/app_config.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late MapState _mapState;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _mapState = context.read<MapState>();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapState.setController(controller);
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      
      // ماركر التحديد فقط إذا يطابق نوع الفلتر (عقار/سيارة)
      final sel = _mapState.selectedMarker;
      if (sel != null) {
        final matchesFilter = (_mapState.filterType == MapFilterType.realEstate &&
                sel.type == MarkerType.property) ||
            (_mapState.filterType == MapFilterType.cars && sel.type == MarkerType.car);
        if (matchesFilter) {
          _markers.add(sel.toGoogleMarker());
        }
      }
      
      // إضافة markers العادية
      for (final marker in _mapState.markers) {
        // ✅ تجنب إضافة marker مكرر (إذا كان نفس ID)
        if (_mapState.selectedMarker?.id != marker.id) {
          _markers.add(marker.toGoogleMarker());
        }
      }
      
      // إضافة cluster markers
      for (final cluster in _mapState.clusters) {
        if (cluster.isCluster()) {
          _markers.add(
            Marker(
              markerId: MarkerId(cluster.id),
              position: cluster.position,
              infoWindow: InfoWindow(
                title: '${cluster.size} عنصر',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
            ),
          );
        } else if (cluster.markers.isNotEmpty) {
          // ✅ تجنب إضافة marker مكرر
          final clusterMarker = cluster.markers.first;
          if (_mapState.selectedMarker?.id != clusterMarker.id) {
            _markers.add(clusterMarker.toGoogleMarker());
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapState>(
      builder: (context, state, child) {
        // تحديث markers عند تغيير state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateMarkers();
        });

        return GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              AppConfig.defaultLatitude,
              AppConfig.defaultLongitude,
            ),
            zoom: AppConfig.defaultZoom,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true, // تفعيل زر الموقع الحالي
          mapType: MapType.normal,
          onCameraMove: _mapState.onCameraMove,
          onCameraIdle: () {
            _mapState.updateMarkers();
          },
        );
      },
    );
  }

}
