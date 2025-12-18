import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CRMSectionScaffold extends StatelessWidget {
  const CRMSectionScaffold({super.key, required this.title, required this.tabs, required this.tabViews, this.actions, this.fab, this.showTitle = true, this.leading});

  final String title;
  final List<Tab> tabs;
  final List<Widget> tabViews;
  final List<Widget>? actions;
  final Widget? fab;
  final bool showTitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bool isTablet = MediaQuery.of(context).size.width >= 600;
    const Color headerStart = Color(0xFFE9F2FF); // light blue tint
    const Color headerEnd = Color(0xFFF6FAFF);   // very light blue
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: fab,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              pinned: true,
              floating: false,
              centerTitle: false,
              leading: leading,
              title: showTitle 
                  ? Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    )
                  : null,
              toolbarHeight: (showTitle || leading != null) ? 72 : 0,
              collapsedHeight: (showTitle || leading != null) ? 72 : 0,
              // Remove gradient background; keep solid white like Tour Plan
              flexibleSpace: null,
              actions: showTitle ? actions : null,
              bottom: TabBar(
                isScrollable: false,
                // Match Tour Plan teal theme
                indicatorColor: const Color(0xFF4db1b3),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF4db1b3),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                tabs: tabs,
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(children: tabViews),
            ),
          ],
        ),
      ),
    );
  }
}


