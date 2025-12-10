import 'package:flutter/material.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/action_card.dart';
import 'checkin_screen.dart';
import 'checkout_screen.dart';
// import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // Match gradient background
      appBar: const CustomAppBar(title: 'Card Scan', showBackButton: false),
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title and Subtitle Section
                        // const Text(
                        //   'Card Scan',
                        //   textAlign: TextAlign.center,
                        //   style: TextStyle(
                        //     color: Colors.white,
                        //     fontSize: 28,
                        //     fontWeight: FontWeight.bold,
                        //     letterSpacing: 1.0,
                        //     height: 1.2,
                        //   ),
                        // ),
                        // const SizedBox(height: 6),
                        // Text(
                        //   'Identity Verification System',
                        //   textAlign: TextAlign.center,
                        //   style: TextStyle(
                        //     color: Colors.white.withOpacity(0.85),
                        //     fontSize: 13,
                        //     letterSpacing: 0.5,
                        //     fontWeight: FontWeight.w400,
                        //   ),
                        // ),
                        // const SizedBox(height: 20),
                        // Action Cards
                        ActionCard(
                          title: 'Check In',
                          icon: Icons.login,
                          iconColor: const Color(0xFF10B981), // Green
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckInScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        ActionCard(
                          title: 'Check Out',
                          icon: Icons.logout,
                          iconColor: const Color(0xFFEF4444), // Red
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckOutScreen(),
                              ),
                            );
                          },
                        ),
                        // const SizedBox(height: 10),
                        // ActionCard(
                        //   title: 'Login',
                        //   icon: Icons.person,
                        //   iconColor: const Color(0xFF3B82F6), // Blue
                        //   onTap: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => const LoginScreen(),
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
