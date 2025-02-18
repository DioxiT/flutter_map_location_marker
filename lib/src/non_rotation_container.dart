import 'package:flutter/widgets.dart';
import 'package:flutter_map/plugin_api.dart';

/// A container that revert the rotation in Flutter Map. This container can be
/// used in a rotation child only. By using this container, the widget inside
/// is shown as in non rotation child.
class NonRotationContainer extends StatelessWidget {
  /// The widget below this widget in the tree.
  final Widget child;

  /// Create a NonRotationContainer.
  const NonRotationContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final map = FlutterMapState.maybeOf(context)!;
    final size = Size(
      map.nonrotatedSize!.x.toDouble(),
      map.nonrotatedSize!.y.toDouble(),
      // todo Use the following code block after flutter_map#1482 is accepted
      /*
      map.nonrotatedSize.x,
      map.nonrotatedSize.y,
       */
    );
    return Transform.rotate(
      angle: -map.rotationRad,
      child: OverflowBox(
        maxWidth: size.width,
        maxHeight: size.height,
        child: SizedBox.fromSize(
          size: size,
          child: child,
        ),
      ),
    );
  }
}
