import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    required this.onInitialize,
  });

  final VoidCallback onFinished;
  final Future<void> Function() onInitialize;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    try {
      await Future.wait<void>(<Future<void>>[
        Future<void>.delayed(const Duration(milliseconds: 250)),
        _initializeFirestoreWithRetry(),
      ]);
      if (!mounted) {
        return;
      }
      widget.onFinished();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _initializeFirestoreWithRetry() async {
    const List<Duration> retryDelays = <Duration>[
      Duration(milliseconds: 120),
      Duration(milliseconds: 350),
      Duration(milliseconds: 700),
    ];

    Object? lastError;
    for (int attempt = 0; attempt < retryDelays.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(retryDelays[attempt]);
      }
      try {
        if (mounted) {
          setState(() {
            _errorMessage = null;
            _isInitializing = true;
          });
        }
        await widget.onInitialize();
        return;
      } catch (error) {
        lastError = error;
        final String message = error.toString();
        final bool isChannelStartupIssue = message.contains(
          'Unable to establish connection on channel',
        );
        if (!isChannelStartupIssue || attempt == retryDelays.length - 1) {
          rethrow;
        }
      }
    }

    throw lastError!;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: 0.093,
              child: Image.asset(
                'image/The Wings Mission Logo (white).png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            if (_isInitializing)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _initialize,
                    child: const Text('Retry'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
