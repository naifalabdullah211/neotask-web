import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';

/// Increment this only when a future manager welcome experience must be shown
/// once again. The acknowledged value is stored on the manager's account.
const int managerWelcomeVersion = 1;

class ManagerWelcomeScreen extends StatefulWidget {
  const ManagerWelcomeScreen({super.key});

  @override
  State<ManagerWelcomeScreen> createState() => _ManagerWelcomeScreenState();
}

class _ManagerWelcomeScreenState extends State<ManagerWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(_fade);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().completeManagerWelcome(
        managerWelcomeVersion,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashRouter()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر حفظ المتابعة، حاول مرة أخرى'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071F42),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          return Stack(
            fit: StackFit.expand,
            children: [
              _PortraitBackground(isCompact: isCompact),
              SafeArea(
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: isCompact
                        ? _CompactWelcomeContent(
                            saving: _saving,
                            onContinue: _continue,
                          )
                        : _WideWelcomeContent(
                            saving: _saving,
                            onContinue: _continue,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortraitBackground extends StatelessWidget {
  const _PortraitBackground({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/manager_welcome_bg.png',
          fit: BoxFit.cover,
          alignment: isCompact
              ? const Alignment(0.45, -1)
              : Alignment.centerRight,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.high,
        ),
        if (isCompact)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.38, 0.62, 1],
                colors: [
                  Color(0x18071F42),
                  Color(0x78071F42),
                  Color(0xF2071F42),
                  Color(0xFF071F42),
                ],
              ),
            ),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, 0.46, 0.72, 1],
                colors: [
                  Color(0xD9071F42),
                  Color(0xA60A2A4E),
                  Color(0x38071F42),
                  Color(0x26000000),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WideWelcomeContent extends StatelessWidget {
  const _WideWelcomeContent({
    required this.saving,
    required this.onContinue,
  });

  final bool saving;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.56,
        heightFactor: 1,
        alignment: Alignment.centerLeft,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: _WelcomeCopy(
                compact: false,
                saving: saving,
                onContinue: onContinue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactWelcomeContent extends StatelessWidget {
  const _CompactWelcomeContent({
    required this.saving,
    required this.onContinue,
  });

  final bool saving;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 310, 24, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (MediaQuery.sizeOf(context).height - 334)
              .clamp(480, 660)
              .toDouble(),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: _WelcomeCopy(
              compact: true,
              saving: saving,
              onContinue: onContinue,
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({
    required this.compact,
    required this.saving,
    required this.onContinue,
  });

  final bool compact;
  final bool saving;
  final VoidCallback onContinue;

  static const _font = 'IBMPlexSansArabic';
  static const _mint = Color(0xFF35D2AA);
  static const _gold = Color(0xFFF4BE31);

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 28.0 : 44.0;
    final welcomeSize = compact ? 25.0 : 40.0;

    return Directionality(
      textDirection: Directionality.of(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            const Text(
              'مرحبًا بكم في تجربة عمل أكثر وضوحًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _font,
                color: Color(0xFF72EDD3),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'دكتور محمد الخلاوي',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: const [
                TextSpan(text: 'حياك الله في '),
                TextSpan(
                  text: 'NeoTask',
                  style: TextStyle(fontFamily: _font),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: TextStyle(
              fontFamily: _font,
              color: _mint,
              fontSize: welcomeSize,
              fontWeight: FontWeight.w700,
              height: 1.22,
            ),
          ),
          SizedBox(height: compact ? 20 : 28),
          const Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 72,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 22 : 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              Image.asset(
                'assets/images/neotask_brand_mark.png',
                width: compact ? 50 : 64,
                height: compact ? 50 : 64,
                fit: BoxFit.contain,
                semanticLabel: context.tr('شعار NeoTask'),
              ),
              SizedBox(width: compact ? 12 : 16),
              Text(
                'NeoTask',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontFamily: _font,
                  color: Colors.white,
                  fontSize: compact ? 34 : 44,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 18 : 24),
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: compact ? 80 : 110),
            color: _mint.withValues(alpha: 0.34),
          ),
          SizedBox(height: compact ? 18 : 24),
          const Text(
            'صُمّم المشروع ليكون عونًا لكم',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              color: Color(0xFFE4ECF5),
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          SizedBox(height: compact ? 20 : 30),
          Center(
            child: SizedBox(
              width: compact ? double.infinity : 330,
              height: compact ? 54 : 64,
              child: ElevatedButton(
                onPressed: saving ? null : onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mint,
                  disabledBackgroundColor: _mint.withValues(alpha: 0.72),
                  foregroundColor: const Color(0xFF06284B),
                  disabledForegroundColor: const Color(0xFF06284B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF06284B),
                        ),
                      )
                    : const Text(
                        'ابدأ الآن على بركة الله',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: compact ? 18 : 24),
          const Text(
            'تظهر هذه الصفحة مرة واحدة عند أول تسجيل دخول',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              color: Color(0xFF8DA3BA),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جميع الحقوق محفوظة · NAY211@2026',
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            style: TextStyle(
              fontFamily: _font,
              color: Color(0xFF7890A9),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
