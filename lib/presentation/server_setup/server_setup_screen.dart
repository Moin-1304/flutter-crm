import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/data/secure_storage/secure_storage_helper.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown on first install when no API base URL is configured.
/// User enters the server base URL which is stored securely and used for all API calls.
class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  final _secureStorage = getIt<SecureStorageHelper>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _inputFocused = false;

  AnimationController? _floatController;
  Animation<double>? _floatAnimation;

  static const _tealGreen = Color(0xFF4db1b3);
  static const _tealLight = Color(0xFF2CC6B8);
  static const _tealDark = Color(0xFF18A7A7);
  static const _softRed = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _urlFocusNode.addListener(() {
      setState(() => _inputFocused = _urlFocusNode.hasFocus);
    });
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _floatController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  Widget _buildHeaderIcon(bool isTablet) {
    final size = isTablet ? 100.0 : 88.0;
    final iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
        color: Colors.white.withOpacity(0.25),
      ),
      child: const Icon(
        Icons.dns_rounded,
        size: 44,
        color: Colors.white,
      ),
    );
    final animation = _floatAnimation;
    if (animation != null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, animation.value),
            child: child,
          );
        },
        child: iconWidget,
      );
    }
    return iconWidget;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the server URL';
    }
    String url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return 'Please enter a valid URL';
      }
    } catch (_) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      String url = text;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      _urlController.text = url;
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _onContinue() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    String url = _urlController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final apiBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    setState(() => _isLoading = true);
    try {
      await _secureStorage.setApiBaseUrl(apiBaseUrl);
      Endpoints.baseUrl = apiBaseUrl;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final titleSize = isTablet ? 34.0 : 30.0;
    final subtitleSize = isTablet ? 16.0 : 15.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4db1b3),
              Color(0xE64db1b3),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 80 : 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Floating icon (animated when controller is ready; static after hot reload)
                    _buildHeaderIcon(isTablet),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'Server Setup',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Enter your API server URL to connect.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Input field with focus glow
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: _inputFocused ? 20 : 12,
                            offset: const Offset(0, 4),
                          ),
                          if (_inputFocused)
                            BoxShadow(
                              color: _tealGreen.withOpacity(0.35),
                              blurRadius: 16,
                              spreadRadius: 0,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextFormField(
                            controller: _urlController,
                            focusNode: _urlFocusNode,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: 'https://your-server.com',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.link_rounded,
                                  color: _tealGreen,
                                  size: 22,
                                ),
                              ),
                              suffixIcon: TextButton.icon(
                                onPressed:
                                    _isLoading ? null : _pasteFromClipboard,
                                icon: const Icon(
                                  Icons.content_paste_rounded,
                                  size: 18,
                                  color: _tealGreen,
                                ),
                                label: const Text(
                                  'Paste',
                                  style: TextStyle(
                                    color: _tealGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              errorStyle: const TextStyle(
                                color: _softRed,
                                fontSize: 13,
                              ),
                            ),
                            validator: _validateUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Example: https://api.yourserver.com',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _softRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _softRed.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: _softRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: _softRed,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Continue button
                    Material(
                      borderRadius: BorderRadius.circular(18),
                      shadowColor: Colors.black.withOpacity(0.25),
                      elevation: 6,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_tealLight, _tealDark],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _tealDark.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                        ),
                      ),
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
}
