import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/eye_gesture_service.dart';

/// Silent wrapper — no visible UI.
/// Responsibilities:
///   1. Intercept pointer events → reset inactivity timer
///   2. Call activateCamera() on the main thread when state → active
class EyeSosOverlay extends StatefulWidget {
  final Widget child;
  const EyeSosOverlay({super.key, required this.child});

  @override
  State<EyeSosOverlay> createState() => _EyeSosOverlayState();
}

class _EyeSosOverlayState extends State<EyeSosOverlay> {
  EyeGestureState? _lastState;

  @override
  Widget build(BuildContext context) {
    return Consumer<EyeGestureService>(
      builder: (context, svc, _) {
        // Trigger camera activation on main thread when state flips to active
        if (svc.state == EyeGestureState.active &&
            _lastState != EyeGestureState.active &&
            !svc.cameraReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            svc.activateCamera();
          });
        }
        _lastState = svc.state;

        return Listener(
          onPointerDown: (_) => svc.onUserInteraction(),
          child: widget.child,
        );
      },
    );
  }
}
