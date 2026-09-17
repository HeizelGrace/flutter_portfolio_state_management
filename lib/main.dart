import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        '/activity-one': (_) => const CounterActivityScreen(),
        '/activity-two': (_) => const LayoutActivityScreen(),
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
                            title: 'Stateful counter',
                            description: 'Practice local state with an interactive counter.',
                            icon: Icons.touch_app_outlined,
                            onTap: () =>
                                Navigator.pushNamed(context, '/activity-one'),
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 16 : 0,
                          height: isWide ? 0 : 16,
                        ),
                        ExpandedOrBox(
                          expanded: isWide,
                          child: ActivityCard(
                            number: '02',
                            title: 'Responsive layout',
                            description: 'Explore flexible widgets that adapt to screen size.',
                            icon: Icons.grid_view_rounded,
                            onTap: () =>
                                Navigator.pushNamed(context, '/activity-two'),
                          ),
                        ),
                      ],
                    ),
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

class CounterActivityScreen extends StatefulWidget {
  const CounterActivityScreen({super.key});

  @override
  State<CounterActivityScreen> createState() => _CounterActivityScreenState();
}

class _CounterActivityScreenState extends State<CounterActivityScreen> {
  int count = 0;

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Activity 01',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_outlined, size: 56),
            const SizedBox(height: 16),
            Text('$count', style: Theme.of(context).textTheme.displayLarge),
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
  );
}

class LayoutActivityScreen extends StatefulWidget {
  const LayoutActivityScreen({super.key});

  @override
  State<LayoutActivityScreen> createState() => _LayoutActivityScreenState();
}

class _LayoutActivityScreenState extends State<LayoutActivityScreen> {
  double progress = .65;

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Activity 02',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: IntrinsicHeight(
            child: Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpandedOrBox(
                  expanded: isWide,
                  child: const InfoPanel(
                    icon: Icons.devices,
                    title: 'Responsive by default',
                    message: 'Resize the window to see this layout move from a row into a column.',
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
