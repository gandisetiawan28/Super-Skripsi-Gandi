import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';

class GlassNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const GlassNavDock({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  static const List<_NavItem> _items = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.architecture_rounded, 'Blueprint'),
    _NavItem(Icons.science_rounded, 'Research'),
    _NavItem(Icons.manage_search_rounded, 'Explorer'),
    _NavItem(Icons.school_rounded, 'Latihan'),
    _NavItem(Icons.webhook_rounded, 'Bridge'),
    _NavItem(Icons.settings_suggest_rounded, 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Give space for shadow
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          ...GlassmorphismTheme.elevatedShadow,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusXL),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassmorphismTheme.blurAmount,
            sigmaY: GlassmorphismTheme.blurAmount,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusXL),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                
                // Logic untuk highlight tab induk jika sedang di halaman detail/hidden
                bool isSelected = index == selectedIndex;
                if (selectedIndex >= _items.length) {
                  // Jika indeks >= 7, berarti di halaman hidden (Keys, Usage, Install, Logs) 
                  // Kita petakan ke tab System (6)
                  if (selectedIndex >= 7 && index == 6) isSelected = true;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _DockButton(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () => onItemTapped(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isSelected ? 16 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? GlassmorphismTheme.primaryRed
                  : _isHovered
                      ? Colors.black.withOpacity(0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusLarge),
              boxShadow: widget.isSelected
                  ? GlassmorphismTheme.redGlowShadow
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color: widget.isSelected
                      ? Colors.white
                      : GlassmorphismTheme.textSecondary,
                ),
                if (widget.isSelected) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
