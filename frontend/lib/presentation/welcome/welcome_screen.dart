import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      final userNotifier = ref.read(userProvider.notifier);
      await userNotifier.initializeUser();
      final userState = ref.read(userProvider);

      if (userState.user != null && mounted) {
        context.pushReplacementNamed(
          'mainNav', // Use the route name instead of AppRoutes.mainNav
          queryParameters: {'tab': '3'}, // Profile tab index
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking auth status: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);

    if (userState.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        Icons.music_note,
                        size: 56,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ArifMusic',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ethiopian Music Streaming',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 48),
                    CustomButton(
                      text: 'Login',
                      onPressed: () => _navigateTo('login'), // Use route name
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Register',
                      isOutlined: true,
                      onPressed: () => _navigateTo('register'), // Use route name
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => _continueAsGuest(),
                      child: const Text('Continue as Guest'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(String routeName) {
    if (mounted) {
      context.pushNamed(routeName); // Use the route name
    }
  }

  void _continueAsGuest() {
    ref.read(userProvider.notifier).logout();
    if (mounted) {
      context.pushReplacementNamed(
        'mainNav',
        queryParameters: {'tab': '0'},
      );
    }
  }
}