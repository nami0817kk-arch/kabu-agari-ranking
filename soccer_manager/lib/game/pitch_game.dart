import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/match_result.dart';

class PitchGame extends FlameGame {
  final MatchResult result;
  final void Function(MatchEvent event) onEvent;
  final VoidCallback onFinished;
  final void Function(int minute)? onMinuteTick;

  PitchGame({
    required this.result,
    required this.onEvent,
    required this.onFinished,
    this.onMinuteTick,
  });

  static const double matchDurationSeconds = 12;

  late CircleComponent _ball;
  double _elapsed = 0;
  int _eventIndex = 0;
  int _lastMinute = 0;
  bool _finished = false;

  @override
  Future<void> onLoad() async {
    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xFF2E7D32)));
    add(RectangleComponent(
      position: Vector2(size.x / 2 - 1, 0),
      size: Vector2(2, size.y),
      paint: Paint()..color = Colors.white.withValues(alpha: 0.6),
    ));
    add(CircleComponent(
      radius: min(size.x, size.y) * 0.28,
      paint: Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      position: size / 2,
      anchor: Anchor.center,
    ));
    _ball = CircleComponent(
      radius: 6,
      paint: Paint()..color = Colors.white,
      position: size / 2,
      anchor: Anchor.center,
    );
    add(_ball);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    _elapsed += dt;
    final progressMinute = (_elapsed / matchDurationSeconds * 90).clamp(0, 90);
    final minuteFloor = progressMinute.floor();
    if (minuteFloor > _lastMinute) {
      _lastMinute = minuteFloor;
      onMinuteTick?.call(_lastMinute);
    }

    final x = size.x / 2 + sin(_elapsed * 1.3) * (size.x / 2 - 16);
    final y = size.y / 2 + cos(_elapsed * 0.9) * (size.y / 2 - 16);
    _ball.position = Vector2(x, y);

    while (_eventIndex < result.events.length && result.events[_eventIndex].minute <= progressMinute) {
      onEvent(result.events[_eventIndex]);
      _eventIndex++;
    }

    if (_elapsed >= matchDurationSeconds && !_finished) {
      _finished = true;
      while (_eventIndex < result.events.length) {
        onEvent(result.events[_eventIndex]);
        _eventIndex++;
      }
      onMinuteTick?.call(90);
      onFinished();
    }
  }
}
