import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_nearby_connections_plus/flutter_nearby_connections_plus.dart';

void main() => runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => NetworkHealthProvider()),
      ChangeNotifierProvider(create: (_) => LocalMeshChatProvider()),
    ],
    child: const PortfolioApp(),
  ),
);

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  void toggleTheme(bool value) {
    _isDark = value;
    notifyListeners();
  }
}

enum NetworkHealth { unknown, testing, excellent, fair, poor, degraded }

enum DiagnosticPhase { idle, idlePing, download, upload, complete }

class NetworkDiagnosticResult {
  const NetworkDiagnosticResult({
    required this.idlePingMs,
    required this.downloadMbps,
    required this.downloadPingMs,
    required this.uploadMbps,
    required this.uploadPingMs,
    required this.health,
  });

  final int idlePingMs;
  final double downloadMbps;
  final int downloadPingMs;
  final double uploadMbps;
  final int uploadPingMs;
  final NetworkHealth health;
}

class NetworkDiagnosticService {
  NetworkDiagnosticService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static final _pingUri = Uri.parse(
    'https://speed.cloudflare.com/cdn-cgi/trace',
  );
  static final _downloadUri = Uri.parse(
    'https://speed.cloudflare.com/__down?bytes=1000000',
  );
  static final _uploadUri = Uri.parse('https://speed.cloudflare.com/__up');

  Future<int> _ping() async {
    final stopwatch = Stopwatch()..start();
    final response = await _client
        .get(_pingUri)
        .timeout(const Duration(seconds: 5));
    stopwatch.stop();
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw Exception('Ping endpoint returned ${response.statusCode}');
    }
    return stopwatch.elapsedMilliseconds;
  }

  Future<double> _downloadMbps() async {
    final stopwatch = Stopwatch()..start();
    final response = await _client
        .get(_downloadUri)
        .timeout(const Duration(seconds: 15));
    stopwatch.stop();
    if (response.statusCode != 200) throw Exception('Download failed');
    return _megabitsPerSecond(response.bodyBytes.length, stopwatch.elapsed);
  }

  Future<double> _uploadMbps() async {
    final payload = List<int>.filled(250000, 65);
    final stopwatch = Stopwatch()..start();
    final response = await _client
        .post(_uploadUri, body: payload)
        .timeout(const Duration(seconds: 15));
    stopwatch.stop();
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw Exception('Upload failed');
    }
    return _megabitsPerSecond(payload.length, stopwatch.elapsed);
  }

  double _megabitsPerSecond(int bytes, Duration elapsed) {
    final seconds = max(
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      0.001,
    );
    return (bytes * 8 / seconds) / 1000000;
  }

  Future<NetworkDiagnosticResult> run({
    void Function(DiagnosticPhase)? onPhase,
  }) async {
    onPhase?.call(DiagnosticPhase.idlePing);
    final idlePing = await _ping();
    onPhase?.call(DiagnosticPhase.download);
    final download = await Future.wait<Object>([_downloadMbps(), _ping()]);
    final downloadMbps = download[0] as double;
    final downloadPingMs = download[1] as int;
    onPhase?.call(DiagnosticPhase.upload);
    final upload = await Future.wait<Object>([_uploadMbps(), _ping()]);
    final uploadMbps = upload[0] as double;
    final uploadPingMs = upload[1] as int;
    final result = NetworkDiagnosticResult(
      idlePingMs: idlePing,
      downloadMbps: downloadMbps,
      downloadPingMs: downloadPingMs,
      uploadMbps: uploadMbps,
      uploadPingMs: uploadPingMs,
      health: classify(
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        idlePingMs: idlePing,
        downloadPingMs: downloadPingMs,
        uploadPingMs: uploadPingMs,
      ),
    );
    onPhase?.call(DiagnosticPhase.complete);
    return result;
  }

  static NetworkHealth classify({
    required double downloadMbps,
    required double uploadMbps,
    required int idlePingMs,
    required int downloadPingMs,
    required int uploadPingMs,
  }) {
    final averagePing = (idlePingMs + downloadPingMs + uploadPingMs) / 3;
    if (averagePing > 500 || idlePingMs > 1000) return NetworkHealth.degraded;
    final bandwidth = min(downloadMbps, uploadMbps);
    if (bandwidth > 10) return NetworkHealth.excellent;
    if (bandwidth >= 2) return NetworkHealth.fair;
    return NetworkHealth.poor;
  }

  void dispose() => _client.close();
}

class NetworkHealthProvider extends ChangeNotifier {
  NetworkHealthProvider({NetworkDiagnosticService? service})
    : _service = service ?? NetworkDiagnosticService();

  final NetworkDiagnosticService _service;
  NetworkHealth _health = NetworkHealth.unknown;
  DiagnosticPhase _phase = DiagnosticPhase.idle;
  NetworkDiagnosticResult? _result;
  String? _error;
  Timer? _timer;
  bool _isRunning = false;

  NetworkHealth get health => _health;
  DiagnosticPhase get phase => _phase;
  NetworkDiagnosticResult? get result => _result;
  String? get error => _error;
  bool get isRunning => _isRunning;

  void start() {
    if (_timer != null) return;
    runNow();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => runNow());
  }

  Future<void> runNow() async {
    if (_isRunning) return;
    _isRunning = true;
    _error = null;
    _health = NetworkHealth.testing;
    notifyListeners();
    try {
      _result = await _service.run(
        onPhase: (phase) {
          _phase = phase;
          notifyListeners();
        },
      );
      _health = _result!.health;
    } catch (exception) {
      _health = NetworkHealth.degraded;
      _error = 'Diagnostic failed: $exception';
      _phase = DiagnosticPhase.complete;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.dispose();
    super.dispose();
  }
}

class PortfolioApp extends StatelessWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return MaterialApp(
      title: 'Charzel\'s Flutter Lab',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const DashboardScreen(),
        '/activity-one': (_) => const ActivityOneScreen(),
        '/activity-two': (_) => const NetworkMonitorScreen(),
        '/network-diagnostic': (_) => const NetworkDiagnosticScreen(),
        '/local-mesh-chat': (_) => const LocalMeshChatScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffe5684f),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xff151515)
        : const Color(0xfff8f5ef),
    useMaterial3: true,
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.tune),
        ),
      ],
    ),
    body: child,
  );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Portfolio lab',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BUILD / LEARN / SHARE',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Charzel\'s Flutter\nportfolio',
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A growing collection of hands-on activities built with declarative UI and thoughtful state.',
                  ),
                  const SizedBox(height: 28),
                  IntrinsicHeight(
                    child: Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExpandedOrBox(
                          expanded: isWide,
                          child: ActivityCard(
                            number: '01',
                            title: 'State & responsive layout',
                            description: 'Practice local state and flexible layouts in one activity.',
                            icon: Icons.dashboard_customize_outlined,
                            onTap: () =>
                                Navigator.pushNamed(context, '/activity-one'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ActivityCard(
                    number: '02',
                    title: 'Network monitor',
                    description: 'Real-time network state with handover detection and automatic request retry.',
                    icon: Icons.wifi_tethering,
                    onTap: () => Navigator.pushNamed(context, '/activity-two'),
                  ),
                  const SizedBox(height: 16),
                  ActivityCard(
                    number: '03',
                    title: 'Network diagnostic dashboard',
                    description: 'Measure ping, download, and upload health to adapt the experience in real time.',
                    icon: Icons.speed_outlined,
                    onTap: () =>
                        Navigator.pushNamed(context, '/network-diagnostic'),
                  ),
                  const SizedBox(height: 16),
                  ActivityCard(
                    number: '04',
                    title: 'Local Mesh Chat',
                    description: 'Serverless P2P messaging that discovers nearby devices and routes text without internet.',
                    icon: Icons.bluetooth_audio,
                    onTap: () =>
                        Navigator.pushNamed(context, '/local-mesh-chat'),
                  ),
                  const SizedBox(height: 24),
                  const InfoPanel(
                    icon: Icons.public,
                    title: 'Global state is live',
                    message: 'Open Settings and switch the theme. This dashboard updates instantly across the app.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ExpandedOrBox extends StatelessWidget {
  const ExpandedOrBox({required this.expanded, required this.child, super.key});
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      expanded ? Expanded(child: child) : child;
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 28),
            Text(number),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_outward),
            ),
          ],
        ),
      ),
    ),
  );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}

class ActivityOneScreen extends StatefulWidget {
  const ActivityOneScreen({super.key});

  @override
  State<ActivityOneScreen> createState() => _ActivityOneScreenState();
}

class _ActivityOneScreenState extends State<ActivityOneScreen> {
  int count = 0;
  double progress = .65;

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Activity 01',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExpandedOrBox(
                    expanded: isWide,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app_outlined, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              '$count',
                              style: Theme.of(context).textTheme.displayLarge,
                            ),
                            const Text('Tap to update local state.'),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => setState(() => count++),
                              icon: const Icon(Icons.add),
                              label: const Text('Increment'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                  ExpandedOrBox(
                    expanded: isWide,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const InfoPanel(
                              icon: Icons.devices,
                              title: 'Responsive by default',
                              message: 'Resize the window to see this layout move from a row into a column.',
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Flexible progress',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 20),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                            ),
                            Slider(
                              value: progress,
                              onChanged: (value) =>
                                  setState(() => progress = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return AppShell(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Preferences',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('These settings are shared by every screen.'),
          const SizedBox(height: 24),
          Card(
            child: SwitchListTile(
              title: const Text('Dark theme'),
              subtitle: const Text('Update the entire portfolio appearance'),
              value: theme.isDark,
              onChanged: theme.toggleTheme,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local Mesh Chat Provider
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isFromMe,
    required this.timestamp,
    this.senderName,
  });

  final String text;
  final bool isFromMe;
  final DateTime timestamp;
  final String? senderName;
}

class NearbyDevice {
  const NearbyDevice({
    required this.deviceId,
    required this.deviceName,
    required this.state,
  });

  final String deviceId;
  final String deviceName;
  final SessionState state;

  bool get isConnected => state == SessionState.connected;
}

class LocalMeshChatProvider extends ChangeNotifier {
  LocalMeshChatProvider() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _nearbyService = NearbyService();
      }
    } catch (e) {
      // Platform not supported (e.g., web)
    }
  }

  NearbyService? _nearbyService;
  final List<NearbyDevice> _devices = [];
  final List<ChatMessage> _messages = [];
  NearbyDevice? _connectedDevice;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _error;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _dataSubscription;

  List<NearbyDevice> get devices => List.unmodifiable(_devices);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  NearbyDevice? get connectedDevice => _connectedDevice;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  String? get error => _error;
  bool get isConnected => _connectedDevice != null;

  bool get isPlatformSupported {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  bool get isIOS {
    try {
      return Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  static const String _serviceType = 'mpconn';

  Future<void> startAdvertising(String deviceName) async {
    if (!isPlatformSupported) {
      _error = 'Platform not supported. Requires Android or iOS.';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      notifyListeners();

      await _nearbyService!.init(
        serviceType: _serviceType,
        deviceName: deviceName,
        strategy: Strategy.P2P_CLUSTER,
        callback: (isRunning) async {
          if (isRunning) {
            await _nearbyService!.stopAdvertisingPeer();
            await _nearbyService!.stopBrowsingForPeers();
            await Future.delayed(const Duration(microseconds: 200));
            await _nearbyService!.startAdvertisingPeer();
            await _nearbyService!.startBrowsingForPeers();
            _isAdvertising = true;
            _isDiscovering = false;
            _addLog('Started advertising as $deviceName');
            notifyListeners();
          }
        },
      );

      _setupListeners();
    } catch (e) {
      _error = 'Failed to start advertising: $e';
      notifyListeners();
    }
  }

  Future<void> startDiscovery(String deviceName) async {
    if (!isPlatformSupported) {
      _error = 'Platform not supported. Requires Android or iOS.';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      notifyListeners();

      await _nearbyService!.init(
        serviceType: _serviceType,
        deviceName: deviceName,
        strategy: Strategy.P2P_CLUSTER,
        callback: (isRunning) async {
          if (isRunning) {
            await _nearbyService!.stopBrowsingForPeers();
            await Future.delayed(const Duration(microseconds: 200));
            await _nearbyService!.startBrowsingForPeers();
            _isDiscovering = true;
            _isAdvertising = false;
            _addLog('Started discovery as $deviceName');
            notifyListeners();
          }
        },
      );

      _setupListeners();
    } catch (e) {
      _error = 'Failed to start discovery: $e';
      notifyListeners();
    }
  }

  void _setupListeners() {
    _stateSubscription = _nearbyService!.stateChangedSubscription(
      callback: (devicesList) {
        for (final device in devicesList) {
          _addDevice(device);
          if (device.state == SessionState.connected) {
            _handleConnection(device);
          } else if (device.state == SessionState.notConnected) {
            _handleDisconnection(device.deviceId);
          }
        }
      },
    );

    _dataSubscription = _nearbyService!.dataReceivedSubscription(
      callback: (data) {
        if (data.containsKey('device_id') && data.containsKey('message')) {
          _handleMessage(data['device_id'], data['message']);
        }
      },
    );
  }

  Future<void> connectToDevice(String deviceId) async {
    if (!isPlatformSupported) {
      _error = 'Platform not supported. Requires Android or iOS.';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      notifyListeners();

      final device = _devices.firstWhere(
        (d) => d.deviceId == deviceId,
        orElse: () => NearbyDevice(
          deviceId: deviceId,
          deviceName: 'Unknown',
          state: SessionState.notConnected,
        ),
      );

      await _nearbyService!.invitePeer(
        deviceID: deviceId,
        deviceName: device.deviceName,
      );
      _addLog('Connecting to ${device.deviceName}...');
    } catch (e) {
      _error = 'Failed to connect: $e';
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (_connectedDevice == null) {
      _error = 'No device connected';
      notifyListeners();
      return;
    }

    if (!isPlatformSupported) {
      _error = 'Platform not supported. Requires Android or iOS.';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      await _nearbyService!.sendMessage(
        _connectedDevice!.deviceId,
        text,
      );

      _addMessage(text, isFromMe: true);
      _addLog('Message sent to ${_connectedDevice!.deviceName}');
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  void disconnect() async {
    if (_connectedDevice != null && _nearbyService != null) {
      await _nearbyService!.disconnectPeer(deviceID: _connectedDevice!.deviceId);
      _handleDisconnection(_connectedDevice!.deviceId);
    }
  }

  void stop() async {
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    if (_nearbyService != null) {
      await _nearbyService!.stopAdvertisingPeer();
      await _nearbyService!.stopBrowsingForPeers();
    }
    _isAdvertising = false;
    _isDiscovering = false;
    _devices.clear();
    _connectedDevice = null;
    _addLog('Stopped advertising/discovery');
    notifyListeners();
  }

  void _handleConnection(Device device) {
    _connectedDevice = NearbyDevice(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      state: device.state,
    );
    _addLog('Connected to ${device.deviceName}');
    notifyListeners();
  }

  void _handleDisconnection(String deviceId) {
    _connectedDevice = null;
    final existingDevice = _devices.firstWhere(
      (d) => d.deviceId == deviceId,
      orElse: () => NearbyDevice(
        deviceId: deviceId,
        deviceName: 'Unknown',
        state: SessionState.notConnected,
      ),
    );
    _addDevice(Device(
      deviceId,
      existingDevice.deviceName,
      0,
    ));
    _addLog('Disconnected from $deviceId');
    notifyListeners();
  }

  void _handleMessage(String deviceId, String payload) {
    final device = _devices.firstWhere(
      (d) => d.deviceId == deviceId,
      orElse: () => NearbyDevice(
        deviceId: deviceId,
        deviceName: 'Unknown',
        state: SessionState.connected,
      ),
    );

    _addMessage(payload, isFromMe: false, senderName: device.deviceName);
    _addLog('Message received from ${device.deviceName}');
  }

  void _addDevice(Device device) {
    final existingIndex = _devices.indexWhere((d) => d.deviceId == device.deviceId);
    if (existingIndex != -1) {
      _devices[existingIndex] = NearbyDevice(
        deviceId: device.deviceId,
        deviceName: device.deviceName.isEmpty ? _devices[existingIndex].deviceName : device.deviceName,
        state: device.state,
      );
    } else {
      _devices.add(NearbyDevice(
        deviceId: device.deviceId,
        deviceName: device.deviceName,
        state: device.state,
      ));
    }
    notifyListeners();
  }

  void _addMessage(String text, {required bool isFromMe, String? senderName}) {
    _messages.add(ChatMessage(
      text: text,
      isFromMe: isFromMe,
      timestamp: DateTime.now(),
      senderName: senderName,
    ));
    notifyListeners();
  }

  void _addLog(String message) {
    debugPrint('[MeshChat] $message');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity 04 — Local Mesh Chat
// ─────────────────────────────────────────────────────────────────────────────

class LocalMeshChatScreen extends StatefulWidget {
  const LocalMeshChatScreen({super.key});

  @override
  State<LocalMeshChatScreen> createState() => _LocalMeshChatScreenState();
}

class _LocalMeshChatScreenState extends State<LocalMeshChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(text: 'Device-${Random().nextInt(9999)}');
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<LocalMeshChatProvider>();
    final scheme = Theme.of(context).colorScheme;

    return AppShell(
      title: 'Local Mesh Chat',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Serverless Local Chat',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover nearby devices and chat without internet. Uses P2P mesh networking via Bluetooth/Wi-Fi.',
                ),
                const SizedBox(height: 24),

                // Platform warning
                if (!chatProvider.isPlatformSupported)
                  Card(
                    color: scheme.error.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: scheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Platform Not Supported',
                                  style: TextStyle(
                                    color: scheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Local Mesh Chat requires Android or iOS real devices. '
                                  'Bluetooth/Wi-Fi P2P is not available on this platform.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (chatProvider.isPlatformSupported && chatProvider.isIOS)
                  Card(
                    color: scheme.primary.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'iOS Setup Required',
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add these permissions to ios/Runner/Info.plist:\n'
                                  '• NSBonjourServices\n'
                                  '• NSBluetoothAlwaysUsageDescription\n'
                                  '• UIRequiresPersistentWiFi',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Device name input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _nameController,
                      enabled: chatProvider.isPlatformSupported,
                      decoration: InputDecoration(
                        labelText: 'Your device name',
                        prefixIcon: const Icon(Icons.devices),
                        border: const OutlineInputBorder(),
                        suffixIcon: !chatProvider.isPlatformSupported
                            ? const Icon(Icons.block, color: Colors.grey)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Connection controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: !chatProvider.isPlatformSupported || chatProvider.isAdvertising
                                    ? null
                                    : () => chatProvider.startAdvertising(_nameController.text),
                                icon: const Icon(Icons.broadcast_on_personal),
                                label: const Text('Advertise'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: !chatProvider.isPlatformSupported || chatProvider.isDiscovering
                                    ? null
                                    : () => chatProvider.startDiscovery(_nameController.text),
                                icon: const Icon(Icons.search),
                                label: const Text('Discover'),
                              ),
                            ),
                          ],
                        ),
                        if (chatProvider.isAdvertising || chatProvider.isDiscovering) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: chatProvider.stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status indicator
                _buildStatusCard(chatProvider, scheme),
                const SizedBox(height: 16),

                // Nearby devices list
                if (chatProvider.devices.isNotEmpty) ...[
                  Text(
                    'NEARBY DEVICES',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  ...chatProvider.devices.map(
                    (device) => Card(
                      color: device.isConnected
                          ? scheme.primary.withValues(alpha: 0.1)
                          : null,
                      child: ListTile(
                        leading: Icon(
                          device.isConnected ? Icons.link : Icons.bluetooth_searching,
                          color: device.isConnected ? scheme.primary : null,
                        ),
                        title: Text(device.deviceName),
                        subtitle: Text(device.deviceId),
                        trailing: device.isConnected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : FilledButton(
                                onPressed: device.state == SessionState.connecting
                                    ? null
                                    : () => chatProvider.connectToDevice(device.deviceId),
                                child: Text(
                                  device.state == SessionState.connecting
                                      ? 'Connecting...'
                                      : 'Connect',
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Error display
                if (chatProvider.error != null) ...[
                  Card(
                    color: scheme.error.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: scheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              chatProvider.error!,
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Chat messages
                if (chatProvider.isConnected) ...[
                  Text(
                    'CHAT',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: chatProvider.messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet. Start chatting!',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: chatProvider.messages.length,
                            itemBuilder: (context, index) {
                              final message = chatProvider.messages[index];
                              return _MessageBubble(message: message);
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // Message input bar
          if (chatProvider.isConnected)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                          chatProvider.sendMessage(text);
                          _messageController.clear();
                          _scrollToBottom();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      if (_messageController.text.isNotEmpty) {
                        chatProvider.sendMessage(_messageController.text);
                        _messageController.clear();
                        _scrollToBottom();
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(LocalMeshChatProvider provider, ColorScheme scheme) {
    String status;
    IconData icon;
    Color color;

    if (provider.isConnected) {
      status = 'Connected to ${provider.connectedDevice?.deviceName ?? 'device'}';
      icon = Icons.link;
      color = Colors.green;
    } else if (provider.isAdvertising) {
      status = 'Advertising - waiting for connections';
      icon = Icons.broadcast_on_personal;
      color = scheme.primary;
    } else if (provider.isDiscovering) {
      status = 'Discovering - scanning for devices';
      icon = Icons.search;
      color = scheme.primary;
    } else {
      status = 'Idle - advertise or discover to start';
      icon = Icons.wifi_off;
      color = scheme.onSurface.withValues(alpha: 0.5);
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            if (provider.isConnected)
              IconButton(
                icon: const Icon(Icons.link_off),
                onPressed: provider.disconnect,
                tooltip: 'Disconnect',
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFromMe = message.isFromMe;

    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isFromMe ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromMe && message.senderName != null)
              Text(
                message.senderName!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isFromMe ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: isFromMe ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isFromMe
                    ? scheme.onPrimary.withValues(alpha: 0.7)
                    : scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity 02 — Network Monitor
// ─────────────────────────────────────────────────────────────────────────────

class NetworkDiagnosticScreen extends StatefulWidget {
  const NetworkDiagnosticScreen({super.key});

  @override
  State<NetworkDiagnosticScreen> createState() =>
      _NetworkDiagnosticScreenState();
}

class _NetworkDiagnosticScreenState extends State<NetworkDiagnosticScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NetworkHealthProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final diagnostic = context.watch<NetworkHealthProvider>();
    final result = diagnostic.result;
    final scheme = Theme.of(context).colorScheme;
    final color = _healthColor(diagnostic.health, scheme);
    return AppShell(
      title: 'Network Diagnostic Dashboard',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Connection health, measured live',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A three-step diagnostic runs every minute and publishes its tier across the app.',
          ),
          const SizedBox(height: 24),
          Card(
            color: color.withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(_healthIcon(diagnostic.health), color: color, size: 42),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT TIER',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _healthLabel(diagnostic.health),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(_phaseLabel(diagnostic.phase)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Run diagnostic now',
                    onPressed: diagnostic.isRunning ? null : diagnostic.runNow,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          if (diagnostic.isRunning) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _phaseProgress(diagnostic.phase)),
          ],
          if (diagnostic.error != null) ...[
            const SizedBox(height: 12),
            Text(diagnostic.error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 650 ? 3 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3.2 : 1.35,
                children: [
                  _MetricCard(
                    label: 'Idle ping',
                    value: _metric(result?.idlePingMs, 'ms'),
                    icon: Icons.radio_button_checked,
                  ),
                  _MetricCard(
                    label: 'Download',
                    value: _metric(result?.downloadMbps, 'Mbps'),
                    icon: Icons.download_outlined,
                  ),
                  _MetricCard(
                    label: 'Download ping',
                    value: _metric(result?.downloadPingMs, 'ms'),
                    icon: Icons.swap_vert,
                  ),
                  _MetricCard(
                    label: 'Upload',
                    value: _metric(result?.uploadMbps, 'Mbps'),
                    icon: Icons.upload_outlined,
                  ),
                  _MetricCard(
                    label: 'Upload ping',
                    value: _metric(result?.uploadPingMs, 'ms'),
                    icon: Icons.swap_vert,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          InfoPanel(
            icon: Icons.auto_awesome,
            title: 'Adaptive delivery policy',
            message: 'Excellent: full-resolution media. Fair: optimized media. Poor: lightweight placeholders. Degraded: offline-first fallback.',
          ),
        ],
      ),
    );
  }

  String _metric(num? value, String unit) => value == null
      ? '--'
      : '${value is double ? value.toStringAsFixed(1) : value} $unit';

  double _phaseProgress(DiagnosticPhase phase) => switch (phase) {
    DiagnosticPhase.idlePing => .2,
    DiagnosticPhase.download => .5,
    DiagnosticPhase.upload => .8,
    DiagnosticPhase.complete => 1,
    DiagnosticPhase.idle => 0,
  };

  String _phaseLabel(DiagnosticPhase phase) => switch (phase) {
    DiagnosticPhase.idle => 'Waiting to start',
    DiagnosticPhase.idlePing => 'Step 1 of 3: measuring idle ping',
    DiagnosticPhase.download => 'Step 2 of 3: download test + concurrent ping',
    DiagnosticPhase.upload => 'Step 3 of 3: upload test + concurrent ping',
    DiagnosticPhase.complete => 'Updated just now',
  };

  String _healthLabel(NetworkHealth health) => switch (health) {
    NetworkHealth.unknown => 'Waiting',
    NetworkHealth.testing => 'Testing',
    NetworkHealth.excellent => 'Excellent',
    NetworkHealth.fair => 'Fair',
    NetworkHealth.poor => 'Poor',
    NetworkHealth.degraded => 'Degraded',
  };

  IconData _healthIcon(NetworkHealth health) => switch (health) {
    NetworkHealth.excellent => Icons.bolt,
    NetworkHealth.fair => Icons.wifi,
    NetworkHealth.poor => Icons.network_check,
    NetworkHealth.degraded => Icons.wifi_off,
    _ => Icons.speed,
  };

  Color _healthColor(NetworkHealth health, ColorScheme scheme) =>
      switch (health) {
        NetworkHealth.excellent => Colors.green,
        NetworkHealth.fair => Colors.orange,
        NetworkHealth.poor => Colors.deepOrange,
        NetworkHealth.degraded => scheme.error,
        _ => scheme.primary,
      };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class NetworkMonitorScreen extends StatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  State<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen> {
  // Tracks the current network type (wifi, mobile, or none)
  ConnectivityResult _status = ConnectivityResult.none;

  // Requests that failed / were queued while offline
  final List<String> _queue = [];

  // Timestamped log entries shown in the UI
  final List<String> _log = [];

  bool _isFetching = false;
  int _reqCounter = 0;

  // Listens to the connectivity stream from connectivity_plus
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    // Subscribe to real-time network changes
    _subscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ── Connectivity helpers ───────────────────────────────────────────────────

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) _onConnectivityChanged(results);
    } catch (_) {
      _log.insert(0, _stamp('Could not read initial network state.'));
    }
  }

  /// Called every time the network changes (e.g. Wi-Fi off → Cellular).
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final previous = _status;

    // Pick the "best" available connection from the list
    ConnectivityResult next;
    if (results.contains(ConnectivityResult.wifi)) {
      next = ConnectivityResult.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      next = ConnectivityResult.mobile;
    } else {
      next = ConnectivityResult.none;
    }

    setState(() {
      _status = next;
      _log.insert(0, _stamp('📡 Network changed → ${_label(next)}'));
      if (_log.length > 40) _log.removeLast();
    });

    // ── Graceful Recovery ──
    // If we were offline and just got a connection back, retry queued requests.
    final wasOffline = previous == ConnectivityResult.none;
    final nowOnline = next != ConnectivityResult.none;
    if (wasOffline && nowOnline && _queue.isNotEmpty) {
      _retryQueue();
    }
  }

  bool get _isOnline => _status != ConnectivityResult.none;

  String _label(ConnectivityResult r) => switch (r) {
    ConnectivityResult.wifi => 'Wi-Fi',
    ConnectivityResult.mobile => 'Cellular',
    _ => 'Offline',
  };

  String _stamp(String msg) {
    final t = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '[$hh:$mm:$ss] $msg';
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _stamp(msg));
      if (_log.length > 40) _log.removeLast();
    });
  }

  // ── Request simulation ─────────────────────────────────────────────────────

  /// Simulates a long-running fetch (4 s). If the connection drops mid-fetch,
  /// the request is caught and added to the queue instead of crashing.
  Future<void> _simulateFetch() async {
    if (_isFetching) return;
    _reqCounter++;
    final id = 'REQ-${_reqCounter.toString().padLeft(3, '0')}';

    // If already offline, queue immediately without attempting
    if (!_isOnline) {
      setState(() => _queue.add(id));
      _addLog('$id → Offline. Added to queue.');
      return;
    }

    setState(() => _isFetching = true);
    _addLog('$id → Starting fetch (simulated 4 s)…');

    try {
      // First half of the simulated request (2 s)
      await Future.delayed(const Duration(seconds: 2));
      if (!_isOnline) throw Exception('Connection lost mid-fetch (handover)');

      // Second half (2 s)
      await Future.delayed(const Duration(seconds: 2));
      if (!_isOnline) throw Exception('Connection lost mid-fetch (handover)');

      _addLog('$id → ✅ Success — data received.');
    } catch (e) {
      // Catch the error gracefully — queue it instead of crashing
      final reason = e.toString().split(': ').last;
      _addLog('$id → ❌ Failed: $reason');
      setState(() => _queue.add(id));
      _addLog('$id → Added to queue for retry.');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  /// Automatically retries all queued requests once a stable connection
  /// is re-established.
  Future<void> _retryQueue() async {
    final toRetry = List<String>.from(_queue);
    setState(() => _queue.clear());
    _addLog('🔄 Retrying ${toRetry.length} queued request(s)…');

    for (final id in toRetry) {
      if (!_isOnline) {
        // Lost connection again during retry loop — re-queue remainder
        setState(() => _queue.insert(0, id));
        _addLog('$id → Lost connection again. Re-queued.');
        break;
      }
      setState(() => _isFetching = true);
      _addLog('$id → Retrying…');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (_isOnline) {
        _addLog('$id → ✅ Retry successful!');
      } else {
        setState(() => _queue.add(id));
        _addLog('$id → ❌ Failed again. Re-queued.');
      }
      setState(() => _isFetching = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Pick colors/icons based on current status
    final (
      Color statusColor,
      IconData statusIcon,
      String statusLabel,
    ) = switch (_status) {
      ConnectivityResult.wifi => (Colors.green, Icons.wifi, 'Wi-Fi'),
      ConnectivityResult.mobile => (
        Colors.blue,
        Icons.signal_cellular_alt,
        'Cellular',
      ),
      _ => (Colors.red, Icons.wifi_off, 'Offline'),
    };

    final scheme = Theme.of(context).colorScheme;

    return AppShell(
      title: 'Activity 02 — Network Monitor',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Status card ─────────────────────────────────────────────────
          Card(
            color: statusColor.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: statusColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 36),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Interface',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                        ),
                        if (_isFetching) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            color: statusColor,
                            backgroundColor: statusColor.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fetching data…',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: statusColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Action buttons ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isFetching ? null : _simulateFetch,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(_isFetching ? 'Fetching…' : 'Simulate Fetch'),
                ),
              ),
              if (_queue.isNotEmpty) ...[
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: (_isOnline && !_isFetching) ? _retryQueue : null,
                  child: Text('Retry Queue (${_queue.length})'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toggle Wi-Fi or mobile data on your device to simulate a handover.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),

          // ── Pending queue ────────────────────────────────────────────────
          if (_queue.isNotEmpty) ...[
            Text(
              'PENDING QUEUE',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(letterSpacing: 1.5, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            ..._queue.map(
              (id) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.hourglass_top,
                      color: Colors.orange,
                    ),
                    title: Text(
                      id,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Waiting for connection to retry…'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Activity log ─────────────────────────────────────────────────
          Text(
            'ACTIVITY LOG',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          _log.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No activity yet. Tap "Simulate Fetch" to begin,\nthen toggle Wi-Fi to see handover handling.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )
              : Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _log.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        _log[i],
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
