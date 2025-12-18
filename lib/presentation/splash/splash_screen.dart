import 'package:flutter/material.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart';
import 'package:boilerplate/di/service_locator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;
  
  final UserStore _userStore = getIt<UserStore>();
  
  bool _isTablet = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // Create animations
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnim = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    _slideAnim = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    // Start staggered animations (parallel fade + scale, then slide)
    _startAnimations();
    
    // Navigate after splash screen duration
    _navigateToNextScreen();
  }

  Future<void> _startAnimations() async {
    // Start fade and scale animations in parallel
    _fadeController.forward();
    _scaleController.forward();
    
    // Wait for fade/scale to complete, then start slide
    await Future.delayed(const Duration(milliseconds: 800));
    _slideController.forward();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for splash screen to display (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check login status and navigate accordingly
    if (_userStore.isUserLoggedIn) {
      Navigator.of(context).pushReplacementNamed(Routes.home);
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.login);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update tablet check based on current context
    final screenWidth = MediaQuery.of(context).size.width;
    _isTablet = screenWidth >= 768;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4db1b3),
              Color(0xE64db1b3), // ~0.9 opacity for subtle depth
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative circles matching punch/login background
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -40,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              // Animated Content
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_fadeAnim, _scaleAnim]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo with slide animation
                            AnimatedBuilder(
                              animation: _slideAnim,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _slideAnim.value),
                                  child: _buildLogo(),
                                );
                              },
                            ),
                            
                            SizedBox(height: _isTablet ? 60 : 40),
                            
                            // App Name
                            Text(
                              'Pharma App',
                              style: TextStyle(
                                fontSize: _isTablet ? 56 : 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            
                            SizedBox(height: _isTablet ? 12 : 8),
                            
                            // Tagline
                            Text(
                              'Your Health, Our Priority',
                              style: TextStyle(
                                fontSize: _isTablet ? 20 : 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 0.5,
                              ),
                            ),
                            
                            SizedBox(height: _isTablet ? 50 : 40),
                            
                            // Decorative Dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) => Padding(
                                padding: EdgeInsets.only(
                                  right: index < 2 ? (_isTablet ? 16 : 12) : 0,
                                ),
                                child: _buildDecorDot(),
                              )),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Bottom Version Text
              Positioned(
                bottom: _isTablet ? 60 : 40,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _fadeAnim,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnim.value,
                      child: Center(
                        child: Text(
                          'Version 1.0',
                          style: TextStyle(
                            fontSize: _isTablet ? 14 : 12,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final logoSize = _isTablet ? 140.0 : 110.0;
    final plusSize = _isTablet ? 70.0 : 55.0;
    final plusBarWidth = _isTablet ? 48.0 : 38.0;
    final plusBarHeight = _isTablet ? 8.0 : 6.0;
    
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF), // #FFFFFF
            Color(0xFFF0F7F5), // #F0F7F5
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: plusSize,
          height: plusSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Horizontal bar
              Container(
                width: plusBarWidth,
                height: plusBarHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A9C8E),
                  borderRadius: BorderRadius.circular(_isTablet ? 4 : 3),
                ),
              ),
              // Vertical bar
              Container(
                width: plusBarHeight,
                height: plusBarWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A9C8E),
                  borderRadius: BorderRadius.circular(_isTablet ? 4 : 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecorDot() {
    return Container(
      width: _isTablet ? 10 : 8,
      height: _isTablet ? 10 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.4),
      ),
    );
  }
}
