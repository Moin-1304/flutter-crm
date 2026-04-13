import 'dart:ui';

import 'package:boilerplate/core/stores/form/form_store.dart';
import 'package:boilerplate/core/widgets/progress_indicator_widget.dart';
import 'package:boilerplate/core/widgets/animated_toast.dart';
import 'package:boilerplate/presentation/home/store/theme/theme_store.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart';
import 'package:boilerplate/utils/device/device_utils.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import '../../di/service_locator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //text controllers:-----------------------------------------------------------
  final TextEditingController _userEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  //stores:---------------------------------------------------------------------
  final ThemeStore _themeStore = getIt<ThemeStore>();
  final FormStore _formStore = getIt<FormStore>();
  final UserStore _userStore = getIt<UserStore>();

  //focus node:-----------------------------------------------------------------
  late FocusNode _passwordFocusNode;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  
  final Color tealGreen = const Color(0xFF4db1b3);

  @override
  void initState() {
    super.initState();
    _userEmailController.text = "";
    _passwordController.text = "";
    _passwordFocusNode = FocusNode();
    _userStore.addListener(() {
      if (_userStore.success) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigate(context);
        });
      }
      if (!_userStore.isLoading && _userStore.errorMessage != null) {
        // Show error when loading is complete and there's an error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorMessage(_userStore.errorMessage!);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final bool isCompactHeight = size.height < 720;
    final bool isCompactWidth = size.width < 360;
    final bool isCompact = isCompactHeight || isCompactWidth;
    final bool isTabletLayout = size.width >= 768;
    final bool isDesktopLayout = size.width >= 1024;
    final int imageFlex = isCompact ? 38 : 45;
    final int formFlex = 100 - imageFlex;

    Widget content = Column(
      children: [
        Expanded(
          flex: imageFlex,
          child: _buildImageSection(),
        ),
        Expanded(
          flex: formFlex,
          child: _buildLoginForm(isCompact),
        ),
      ],
    );

    if (isTabletLayout) {
      content = _buildTabletLayout(
        isCompact: isCompact,
        isDesktop: isDesktopLayout,
        screenSize: size,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          content,
          AnimatedBuilder(
            animation: _userStore,
            builder: (context, _) {
              return Visibility(
                visible: _userStore.isLoading,
                child: const CustomProgressIndicatorWidget(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout({
    required bool isCompact,
    required bool isDesktop,
    required Size screenSize,
  }) {
    final double horizontalPadding = isDesktop ? 72 : 48;
    final double verticalPadding = isDesktop ? 56 : 40;
    final double contentSpacing = isDesktop ? 40 : 32;
    // Wider form on tablets so the panel does not feel tiny on iPad.
    final double maxFormWidth = isDesktop ? 620 : 540;
    // Taller card on tablet so the login column has room for hero + fields without clipping.
    final double targetHeight = (screenSize.height * (isDesktop ? 0.72 : 0.68))
        .clamp(isDesktop ? 560.0 : 520.0, screenSize.height * 0.88);
    final double maxContentWidth =
        (screenSize.width - (horizontalPadding * 2)).clamp(0.0, isDesktop ? 1320.0 : 1140.0).toDouble();

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              tealGreen.withOpacity(0.06),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -40,
              child: _buildBlurCircle(220, tealGreen.withOpacity(0.18)),
            ),
            Positioned(
              bottom: -80,
              right: -50,
              child: _buildBlurCircle(280, tealGreen.withOpacity(0.12)),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: SizedBox(
                  width: maxContentWidth,
                  height: targetHeight,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 50,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: _buildImageSection(
                                borderRadius: BorderRadius.circular(44),
                              ),
                            ),
                            Positioned(
                              left: 32,
                              right: 32,
                              bottom: 32,
                              child: _buildGlassInfoPanel(isDesktop),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: contentSpacing),
                      Expanded(
                        flex: 50,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxFormWidth,
                              maxHeight: targetHeight,
                            ),
                            child: _buildLoginForm(
                              isCompact,
                              isTabletLayout: true,
                            ),
                          ),
                        ),
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
  }

  Widget _buildImageSection({BorderRadius? borderRadius}) {
    return ClipRRect(
      borderRadius: borderRadius ??
          const BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tealGreen,
              tealGreen.withOpacity(0.9),
            ],
          ),
        ),
        child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // Preserve existing curved image banner on top of gradient background
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.asset(
                  'assets/images/login.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLoginForm(
    bool isCompact, {
    bool isTabletLayout = false,
  }) {
    final bool showTabletHero = isTabletLayout && !isCompact;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isTabletLayout
            ? BorderRadius.circular(32)
            : const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
        boxShadow: isTabletLayout
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: isTabletLayout,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableHeight = constraints.maxHeight;
            final bool ultraCompact = availableHeight < 420;
            final bool compact = isCompact || ultraCompact;

            final double horizontalPadding = ultraCompact ? 16 : (isCompact ? 20 : 28);
            final double verticalPadding = ultraCompact ? 12 : (isCompact ? 16 : 24); // Reduced from 18, 24, 36
            final double brandSpacing = ultraCompact ? 16 : (isCompact ? 22 : 32); // Reduced from 20, 28, 44
            final double fieldSpacing = ultraCompact ? 12 : (isCompact ? 16 : 20);
            final double rowSpacing = ultraCompact ? 10 : (isCompact ? 12 : 16);
            final double buttonSpacing = ultraCompact ? 18 : (isCompact ? 24 : 30); // Reduced from 20, 26, 36
            final double buttonHeight = ultraCompact ? 44 : (isCompact ? 48 : 56);

            final double heroSpacing = showTabletHero ? 18 : 10;
            // Tablet hero + fields can exceed a fixed card height; always allow scroll there.
            final bool allowScroll =
                isTabletLayout || availableHeight < 480;

            return SingleChildScrollView(
              primary: false,
              physics: allowScroll
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                    mainAxisSize: MainAxisSize.max, // Take up full height to allow centering
                    children: [
                      if (showTabletHero) ...[
                        // Theme uses Inter globally; emoji do not render (tofu / "?"). Use Material icon.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontSize: isTabletLayout ? 36 : 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey[900],
                                  letterSpacing: -1,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.waving_hand,
                                size: isTabletLayout ? 34 : 28,
                                color: tealGreen,
                                semanticLabel: 'Wave',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: heroSpacing),
                        Text(
                          'Sign in to review daily calls, approve expenses and stay in sync with your field team.',
                          style: TextStyle(
                            fontSize: isTabletLayout ? 16 : 15,
                            height: 1.45,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Pharma App',
                          style: TextStyle(
                            fontSize: ultraCompact ? 26 : (isCompact ? 28 : 34),
                            fontWeight: FontWeight.w900,
                            color: Colors.grey[900],
                            letterSpacing: -1,
                            height: 1.12,
                          ),
                        ),
                        SizedBox(height: ultraCompact ? 6 : (isCompact ? 8 : 10)),
                        Text(
                          'Your Health, Our Priority',
                          style: TextStyle(
                            fontSize: ultraCompact ? 12 : (isCompact ? 13 : 15),
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                      SizedBox(height: brandSpacing),
                      _buildEmailField(compact),
                      SizedBox(height: fieldSpacing),
                      _buildPasswordField(compact),
                      SizedBox(height: rowSpacing),
                      Row(
                        children: [
                          Transform.scale(
                            scale: compact ? 0.82 : 0.9,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: tealGreen,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(vertical: -4, horizontal: -4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _rememberMe = !_rememberMe;
                              });
                            },
                            child: Text(
                              'Remember me',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: compact ? 12.5 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              // Handle forgot password
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: tealGreen,
                                fontSize: compact ? 12.5 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: buttonSpacing),
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: FilledButton(
                          onPressed: () async {
                            if (_formStore.canLogin) {
                              DeviceUtils.hideKeyboard(context);
                              try {
                                await _userStore.login(
                                  _userEmailController.text,
                                  _passwordController.text,
                                );
                                // Error handling is done by the listener when isLoading becomes false
                              } catch (e) {
                                // Error is handled by UserStore and will show via listener
                                // The finally block ensures isLoading is set to false
                              }
                            } else {
                              _showErrorMessage('Please fill in all fields');
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: tealGreen,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: tealGreen.withOpacity(0.4),
                            padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontSize: compact ? 15 : 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      if (!compact) const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassInfoPanel(bool isDesktop) {
    final double padding = isDesktop ? 24 : 20;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: tealGreen.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage your field force smarter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track tours, daily call reports and approvals from a single dashboard.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildStatBadge('120+', 'Daily visits tracked'),
                  const SizedBox(width: 16),
                  _buildStatBadge('98%', 'On-time approvals'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tealGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(bool isCompact) {
    return Observer(
      builder: (context) {
        final hasError = _formStore.formErrorStore.userEmail?.isNotEmpty == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _userEmailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (v) => _formStore.setUserId(v),
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                style: TextStyle(
                  color: Colors.grey[900],
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Username or Email',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isCompact ? 14 : 15,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: hasError ? Colors.red[400] : Colors.grey[500],
                    size: 22,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red[400]! : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red[400]! : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red[400]! : tealGreen,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.red[400]!,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.red[400]!,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: isCompact ? 14 : 18),
                  errorStyle: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  errorText: _formStore.formErrorStore.userEmail?.isEmpty == true
                      ? null
                      : _formStore.formErrorStore.userEmail,
                ),
                autofillHints: const [AutofillHints.username, AutofillHints.email],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPasswordField(bool isCompact) {
    return Observer(
      builder: (context) {
        final hasError = _formStore.formErrorStore.password?.isNotEmpty == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                onChanged: (v) => _formStore.setPassword(v),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_formStore.canLogin) {
                    DeviceUtils.hideKeyboard(context);
                    _userStore.login(_userEmailController.text, _passwordController.text);
                  }
                },
                style: TextStyle(
                  color: Colors.grey[900],
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isCompact ? 14 : 15,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: hasError ? Colors.red[400] : Colors.grey[500],
                    size: 22,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: hasError ? Colors.red[400] : Colors.grey[500],
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red[400]! : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red[400]! : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: hasError ? Colors.red[400]! : tealGreen,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.red[400]!,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.red[400]!,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: isCompact ? 14 : 18),
                  errorStyle: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  errorText: _formStore.formErrorStore.password?.isEmpty == true
                      ? null
                      : _formStore.formErrorStore.password,
                ),
                autofillHints: const [AutofillHints.password],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget navigate(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 0), () {
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.home,
        (Route<dynamic> route) => false,
      );
    });

    return Container();
  }

  /// Message shown when server is unreachable (wrong URL, etc.). When this
  /// error occurs we show a dialog with an option to go to Server Setup.
  static const String _serverConnectionErrorSubstring = 'check the server URL in Server Setup';

  // General Methods:-----------------------------------------------------------
  _showErrorMessage(String message) {
    if (message.isEmpty) return const SizedBox.shrink();

    Future.delayed(const Duration(milliseconds: 0), () {
      if (!mounted || message.isEmpty) return;

      final isServerConnectionError = message.contains(_serverConnectionErrorSubstring);

      if (isServerConnectionError) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tealGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: tealGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Connection Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            content: Text(
              message,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('OK'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacementNamed(Routes.serverSetup);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tealGreen,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: tealGreen.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Server Setup'),
              ),
            ],
          ),
        );
      } else {
        AnimatedToast.showError(
          context,
          message,
          title: 'Error',
        );
      }
    });

    return const SizedBox.shrink();
  }

  // dispose:-------------------------------------------------------------------
  @override
  void dispose() {
    // Clean up the controller when the Widget is removed from the Widget tree
    _userEmailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}
