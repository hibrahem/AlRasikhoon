// This is the ONE file under lib/core/telemetry/ permitted to import a
// package: `uuid` is pure Dart with no framework or vendor coupling, so
// importing it here does not violate the ports-stay-pure rule the rest of
// this directory follows.
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// A per-invocation id sent with every callable request and echoed into the
/// function's structured log, so a client-side error report and a server-side
/// log line can be joined. It is a random UUID and carries no user data.
String newClientTraceId() => _uuid.v4();
