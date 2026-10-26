import 'dart:math';

final Random _rng = Random.secure();
int _counter = 0;

/// Short unique id: time + counter + random. No external package needed.
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final c = (_counter++).toRadixString(36);
  final r = _rng.nextInt(1 << 32).toRadixString(36);
  return '$t$c$r';
}
