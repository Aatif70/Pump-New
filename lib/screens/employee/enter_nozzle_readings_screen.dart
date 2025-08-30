import 'package:flutter/material.dart';
import '../../theme.dart';
import 'submit_start_reading_screen.dart';
import 'submit_end_reading_screen.dart';
import 'submit_sales_screen.dart';
import 'submit_testing_reading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class EnterNozzleReadingsScreen extends StatefulWidget {
  final String? nozzleId;
  final String? shiftId;
  final String? fuelTankId;
  final String? petrolPumpId;

  const EnterNozzleReadingsScreen({
    Key? key,
    this.nozzleId,
    this.shiftId,
    this.fuelTankId,
    this.petrolPumpId,
  }) : super(key: key);

  @override
  State<EnterNozzleReadingsScreen> createState() => _EnterNozzleReadingsScreenState();
}

class _EnterNozzleReadingsScreenState extends State<EnterNozzleReadingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardController;
  late Animation<double> _headerAnimation;
  late Animation<double> _cardAnimation;
  late List<AnimationController> _cardControllers;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    // Header animation
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );

    // Card stagger animation
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );

    // Individual card animations
    _cardControllers = List.generate(4, (index) =>
        AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        )
    );

    _cardAnimations = _cardControllers.map((controller) =>
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        )
    ).toList();

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    _headerController.forward();

    // Stagger card animations
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + (i * 150)), () {
        if (mounted) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Animated App Bar
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _headerAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - _headerAnimation.value)),
                    child: Opacity(
                      opacity: _headerAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.primaryBlue.withOpacity(0.8),
                              const Color(0xFF6366F1),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Decorative circles
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
                              top: 50,
                              right: -100,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                            ),
                            // Content
                            Positioned(
                              bottom: 30,
                              left: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'SHIFT MANAGEMENT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nozzle Readings',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select an option below to submit your shift data',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Main content with animated cards
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 10),

                // Card animations
                ...List.generate(4, (index) {
                  final cardData = [
                    {
                      'title': 'Submit Start Reading',
                      'subtitle': 'Record the initial meter reading',
                      'icon': Icons.play_circle_outline,
                      'color': const Color(0xFF10B981),
                      'gradientColors': [const Color(0xFF10B981), const Color(0xFF059669)],
                      'onTap': () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SubmitStartReadingScreen(
                                nozzleId: widget.nozzleId,
                                shiftId: widget.shiftId,
                                fuelTankId: widget.fuelTankId,
                                petrolPumpId: widget.petrolPumpId,
                              )
                          )
                      ),
                    },
                    {
                      'title': 'Submit End Reading',
                      'subtitle': 'Record the final meter reading',
                      'icon': Icons.stop_circle_outlined,
                      'color': const Color(0xFFEF4444),
                      'gradientColors': [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                      'onTap': () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SubmitEndReadingScreen(
                                nozzleId: widget.nozzleId,
                                shiftId: widget.shiftId,
                                fuelTankId: widget.fuelTankId,
                                petrolPumpId: widget.petrolPumpId,
                              )
                          )
                      ),
                    },
                    {
                      'title': 'Submit Sales',
                      'subtitle': 'Record the total sales for the shift',
                      'icon': Icons.payments_outlined,
                      'color': const Color(0xFF8B5CF6),
                      'gradientColors': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                      'onTap': () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SubmitSalesScreen(
                                nozzleId: widget.nozzleId,
                                shiftId: widget.shiftId,
                                fuelDispenserId: '',
                              )
                          )
                      ),
                    },
                    {
                      'title': 'Submit Testing',
                      'subtitle': 'Submit the test volume',
                      'icon': Icons.science_outlined,
                      'color': const Color(0xFFF59E0B),
                      'gradientColors': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      'onTap': () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SubmitTestingReadingScreen(
                                nozzleId: widget.nozzleId,
                                shiftId: widget.shiftId,
                                fuelTankId: widget.fuelTankId,
                                petrolPumpId: widget.petrolPumpId,
                              )
                          )
                      ),
                    },
                  ];

                  return Column(
                    children: [
                      AnimatedBuilder(
                        animation: _cardAnimations[index],
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - _cardAnimations[index].value)),
                            child: Opacity(
                              opacity: _cardAnimations[index].value,
                              child: _buildEnhancedActionCard(
                                context: context,
                                title: cardData[index]['title'] as String,
                                subtitle: cardData[index]['subtitle'] as String,
                                icon: cardData[index]['icon'] as IconData,
                                color: cardData[index]['color'] as Color,
                                gradientColors: cardData[index]['gradientColors'] as List<Color>,
                                onTap: cardData[index]['onTap'] as VoidCallback,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Icon container with gradient
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow with subtle animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(2 * value, 0),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: color,
                              size: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}