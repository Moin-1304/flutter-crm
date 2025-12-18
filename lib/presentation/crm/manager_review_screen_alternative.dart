import 'package:flutter/material.dart';
import 'dcr/dcr_manager_review_screen.dart';
import 'expense/expense_manager_review_screen.dart';

/// Alternative Manager Review screen with modern segmented control design
class ManagerReviewScreenAlternative extends StatefulWidget {
  const ManagerReviewScreenAlternative({super.key});

  @override
  State<ManagerReviewScreenAlternative> createState() => _ManagerReviewScreenAlternativeState();
}

class _ManagerReviewScreenAlternativeState extends State<ManagerReviewScreenAlternative> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<TabOption> _tabs = [
    TabOption(
      icon: Icons.description_outlined,
      label: 'DCR',
      color: Colors.blue,
    ),
    TabOption(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Expense',
      color: Colors.green,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {}); // trigger child rebuilds
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.fromLTRB(
              16, 
              MediaQuery.of(context).padding.top + 16, 
              16, 
              16
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manager Review',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Modern Segmented Control
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: _tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tab = entry.value;
                      final isSelected = _selectedIndex == index;
                      
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: tab.color.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 18,
                                  color: isSelected ? tab.color : Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab.label,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: isSelected ? tab.color : Colors.grey[600],
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                DcrManagerReviewScreen(),
                ExpenseManagerReviewScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TabOption {
  final IconData icon;
  final String label;
  final Color color;

  TabOption({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Even more modern version with pill-style tabs
class ManagerReviewScreenModern extends StatefulWidget {
  const ManagerReviewScreenModern({super.key});

  @override
  State<ManagerReviewScreenModern> createState() => _ManagerReviewScreenModernState();
}

class _ManagerReviewScreenModernState extends State<ManagerReviewScreenModern>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header with gradient
          Container(
            padding: EdgeInsets.fromLTRB(
              20, 
              MediaQuery.of(context).padding.top + 20, 
              20, 
              24
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[600]!,
                  Colors.blue[400]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manager Review',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review and approve DCRs and Expenses',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Floating Tab Selector
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Animated Background
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Positioned(
                            left: _selectedIndex * (screenWidth - 40) / 2 + 4,
                            top: 4,
                            child: Container(
                              width: (screenWidth - 40) / 2 - 8,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Tab Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernTabButton(
                              context: context,
                              index: 0,
                              icon: Icons.description_outlined,
                              label: 'DCR',
                              isSelected: _selectedIndex == 0,
                              onTap: () => _onTabSelected(0),
                            ),
                          ),
                          Expanded(
                            child: _buildModernTabButton(
                              context: context,
                              index: 1,
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Expense',
                              isSelected: _selectedIndex == 1,
                              onTap: () => _onTabSelected(1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  DcrManagerReviewScreen(),
                  ExpenseManagerReviewScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _animationController.forward();
  }

  Widget _buildModernTabButton({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

