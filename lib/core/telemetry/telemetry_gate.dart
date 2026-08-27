/// A mutable on/off switch consulted by every adapter before it emits.
///
/// Held as a single instance created in `main()` and shared by the adapters,
/// so the user's opt-out toggle takes effect immediately without an app
/// restart.
class TelemetryGate {
  TelemetryGate({required bool isOpen}) : _isOpen = isOpen;

  bool _isOpen;

  bool get isOpen => _isOpen;

  void open() => _isOpen = true;
  void close() => _isOpen = false;
}
