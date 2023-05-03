import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import 'current_location_layer.dart';
import 'data.dart';
import 'exception/incorrect_setup_exception.dart';
import 'exception/permission_denied_exception.dart' as lm;
import 'exception/permission_requesting_exception.dart' as lm;
import 'exception/service_disabled_exception.dart';

/// Helper class for converting the data stream which provide data in required
/// format from stream created by some existing plugin.
class LocationMarkerDataStreamFactory {
  /// Create a LocationMarkerDataStreamFactory.
  const LocationMarkerDataStreamFactory();

  /// Cast to a position stream from
  /// [geolocator](https://pub.dev/packages/geolocator) stream.
  Stream<LocationMarkerPosition?> fromGeolocatorPositionStream({
    Stream<LocationData?>? stream,
  }) {
    return (stream ?? defaultPositionStreamSource()).map((LocationData? position) {
      return position != null
          ? LocationMarkerPosition(
              latitude: position.latitude ?? 0,
              longitude: position.longitude ?? 0,
              accuracy: position.accuracy ?? 0,
            )
          : null;
    });
  }

  /// Cast to a position stream from
  /// [geolocator](https://pub.dev/packages/geolocator) stream.
  @Deprecated('Use fromGeolocatorPositionStream instead')
  Stream<LocationMarkerPosition?> geolocatorPositionStream({
    Stream<LocationData?>? stream,
  }) =>
      fromGeolocatorPositionStream(
        stream: stream,
      );

  /// Create a position stream which is used as default value of
  /// [CurrentLocationLayer.positionStream].
  Stream<LocationData?> defaultPositionStreamSource() {
    final Location location = Location();
    final List<AsyncCallback> cancelFunctions = [];
    final streamController = StreamController<LocationData?>.broadcast(
      onCancel: () => Future.wait(cancelFunctions.map((callback) => callback())),
    );
    streamController.onListen = () async {
      try {
        // bool serviceEnabled = await location.serviceEnabled();
        PermissionStatus permission = await location.hasPermission();
        // LocationPermission permission = await Geolocator.checkPermission();
        if (permission == PermissionStatus.denied) {
          streamController.sink.addError(const lm.PermissionRequestingException());
          permission = await location.requestPermission();
        }
        switch (permission) {
          case PermissionStatus.denied:
          case PermissionStatus.deniedForever:
            streamController.sink
              ..addError(const lm.PermissionDeniedException())
              ..close();
            break;
          case PermissionStatus.granted:
          case PermissionStatus.grantedLimited:
            try {
              final serviceEnabled = await location.serviceEnabled();
              if (!serviceEnabled) {
                streamController.sink.addError(const ServiceDisabledException());
              }
            } catch (_) {}
            // try {
            //   final subscription =
            //       Geolocator.getServiceStatusStream().listen((serviceStatus) {
            //     if (serviceStatus == ServiceStatus.enabled) {
            //       streamController.sink.add(null);
            //     } else {
            //       streamController.sink
            //           .addError(const ServiceDisabledException());
            //     }
            //   });
            //   cancelFunctions.add(subscription.cancel);
            // } catch (_) {}
            try {
              final lastKnown = await location.getLocation();
              streamController.sink.add(lastKnown);
            } catch (_) {}
            // try {
            //   streamController.sink.add(await Geolocator.getCurrentPosition());
            // } catch (_) {}
            final subscription = location.onLocationChanged.listen((position) {
              streamController.sink.add(position);
            });
            cancelFunctions.add(subscription.cancel);
            break;
        }
      } catch (e) {
        streamController.sink.addError(const IncorrectSetupException());
      }
    };
    return streamController.stream;
  }

  /// Cast to a heading stream from
  /// [flutter_compass](https://pub.dev/packages/flutter_compass) stream.
  Stream<LocationMarkerHeading?> fromCompassHeadingStream({
    Stream<CompassEvent?>? stream,
    double minAccuracy = pi * 0.1,
    double defAccuracy = pi * 0.3,
    double maxAccuracy = pi * 0.4,
  }) {
    return (stream ?? defaultHeadingStreamSource()).where((CompassEvent? e) => e == null || e.heading != null).map(
      (CompassEvent? e) {
        return e != null
            ? LocationMarkerHeading(
                heading: degToRadian(e.heading!),
                accuracy: (e.accuracy ?? defAccuracy).clamp(
                  minAccuracy,
                  maxAccuracy,
                ),
              )
            : null;
      },
    );
  }

  /// Cast to a heading stream from
  /// [flutter_compass](https://pub.dev/packages/flutter_compass) stream.
  @Deprecated('Use fromCompassHeadingStream instead')
  Stream<LocationMarkerHeading?> compassHeadingStream({
    Stream<CompassEvent?>? stream,
    double minAccuracy = pi * 0.1,
    double defAccuracy = pi * 0.3,
    double maxAccuracy = pi * 0.4,
  }) =>
      fromCompassHeadingStream(
        stream: stream,
        minAccuracy: minAccuracy,
        defAccuracy: defAccuracy,
        maxAccuracy: maxAccuracy,
      );

  /// Create a heading stream which is used as default value of
  /// [CurrentLocationLayer.headingStream].
  Stream<CompassEvent?> defaultHeadingStreamSource() {
    return !kIsWeb ? FlutterCompass.events! : const Stream.empty();
  }
}
