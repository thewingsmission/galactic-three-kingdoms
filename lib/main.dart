import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_session_state.dart';
import 'models/soldier_design_palette.dart';
import 'screens/inventory_screen.dart';
import 'screens/main_screen.dart';
import 'screens/soldier_design_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/war_screen.dart';

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    pageBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation) {
      return child;
    },
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GalacticGameplayApp());
}

class GalacticGameplayApp extends StatelessWidget {
  const GalacticGameplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galactic Three Kingdoms — Gameplay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // Player faction (Three Kingdoms — yellow / imperial gold).
          seedColor: const Color(0xFFFFC107),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppFlow(),
    );
  }
}

class AppFlow extends StatefulWidget {
  const AppFlow({super.key});

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GameSessionState _session = GameSessionState();

  void _showMainScreen() {
    _navigatorKey.currentState?.pushReplacement<void, void>(
      _instantRoute<void>(
        MainScreen(
          onOpenInventory: _openInventory,
          onOpenWar: _openWar,
          onOpenDesigns: _openDesigns,
        ),
      ),
    );
  }

  Future<void> _openInventory() async {
    await _navigatorKey.currentState?.push<void>(
      _instantRoute<void>(
        InventoryScreen(session: _session),
      ),
    );
  }

  Future<void> _openWar() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final deployment = _session.buildDeployment();
    if (deployment.soldiers.isEmpty) {
      final BuildContext? screenContext = navigator.context;
      if (screenContext == null) return;
      ScaffoldMessenger.of(screenContext).showSnackBar(
        const SnackBar(content: Text('Select at least one soldier in Inventory first.')),
      );
      return;
    }

    await navigator.push<void>(
      _instantRoute<void>(
        WarScreen(
          deployment: deployment.copy(),
          playerPalette: _session.palette,
        ),
      ),
    );
  }

  Future<void> _openDesigns() async {
    final SoldierDesignPalette? result = await _navigatorKey.currentState?.push<SoldierDesignPalette>(
      _instantRoute<SoldierDesignPalette>(
        SoldierDesignScreen(
          initialPalette: _session.palette,
        ),
      ),
    );
    if (result != null) {
      setState(() => _session.palette = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return _instantRoute<void>(
          SplashScreen(onFinished: _showMainScreen),
        );
      },
    );
  }
}
