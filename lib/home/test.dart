import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ZoomableTextPage extends StatefulWidget {
  const ZoomableTextPage({super.key});

  @override
  State<ZoomableTextPage> createState() => _ZoomableTextPageState();
}

class _ZoomableTextPageState extends State<ZoomableTextPage> {
  double _baseScale = 1.0;
  double _gestureScale = 1.0;

  bool get _isScaling => _gestureScale != 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pinch to Zoom (with Scroll)')),
      body: RawGestureDetector(
        gestures: {
          CustomScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            CustomScaleGestureRecognizer
          >(() => CustomScaleGestureRecognizer(), (
            CustomScaleGestureRecognizer instance,
          ) {
            instance
              ..onStart = (details) {
                _gestureScale = 1.0;
              }
              ..onUpdate = (details) {
                setState(() {
                  _gestureScale = details.scale.clamp(0.5, 3.0);
                });
              }
              ..onEnd = (details) {
                setState(() {
                  _baseScale = (_baseScale * _gestureScale).clamp(0.5, 3.0);
                  _gestureScale = 1.0;
                });
              };
          }),
        },
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Transform.scale(
              scale: _isScaling ? _gestureScale : 1.0,
              alignment: Alignment.topCenter,
              child: Text(
                _largeText,
                style: TextStyle(fontSize: 18 * _baseScale),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const String _largeText = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vivamus lacinia odio vitae vestibulum vestibulum.
Cras venenatis euismod malesuada.
Sed sit amet facilisis urna.
Ut aliquet tristique nisl vitae volutpat.
Scroll me. Pinch me.
''';

/// Custom recognizer that listens only for scaling (pinch) gestures
class CustomScaleGestureRecognizer extends ScaleGestureRecognizer {
  CustomScaleGestureRecognizer({super.debugOwner});

  @override
  void rejectGesture(int pointer) {
    // Don't reject just because another gesture (e.g., scroll) won
    acceptGesture(pointer);
  }
}
