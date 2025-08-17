import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:proxinet/proxinet/proxinet_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ProxinetOnboardingPage extends StatefulWidget {
  const ProxinetOnboardingPage({super.key});

  @override
  State<ProxinetOnboardingPage> createState() => _ProxinetOnboardingPageState();
}

class _ProxinetOnboardingPageState extends State<ProxinetOnboardingPage> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<_OnboardSlide> _slides = const [
    _OnboardSlide(
      title: 'Predictive Meetups',
      subtitle:
          'Get heads-up alerts when your contacts will be nearby at cities and events.',
      icon: Icons.auto_awesome,
      gradient: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
    ),
    _OnboardSlide(
      title: 'Privacy-First',
      subtitle:
          'On-device matching. No raw location or contacts stored on servers.',
      icon: Icons.verified_user,
      gradient: [Color(0xFF059669), Color(0xFF10B981)],
    ),
    _OnboardSlide(
      title: 'Event Mode',
      subtitle:
          'Optional venue mode for quick proximity hints in the foreground.',
      icon: Icons.event_available,
      gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.network_check,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ProxiNet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemBuilder: (context, index) =>
                    _OnboardCard(slide: _slides[index]),
              ),
            ),
            const SizedBox(height: 12),
            _Dots(count: _slides.length, index: _pageIndex),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.go(ProxinetRouter.home);
                      },
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (_pageIndex < _slides.length - 1) {
                            _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          } else {
                            context.go(ProxinetRouter.home);
                          }
                        },
                        child: Text(
                          _pageIndex == _slides.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  const _OnboardSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _OnboardCard extends StatelessWidget {
  final _OnboardSlide slide;
  const _OnboardCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: slide.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(slide.icon, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(slide.title,
                style: theme.textTheme.displaySmall
                    ?.copyWith(color: Colors.white)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                slide.subtitle,
                style:
                    theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
