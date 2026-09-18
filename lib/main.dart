import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() => runApp(
  ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
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
// Activity 02 — Network Monitor
// ─────────────────────────────────────────────────────────────────────────────

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
