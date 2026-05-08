import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final bool elevated;
  final bool animateEntrance;
  final Duration entranceDelay;
  final bool hoverEffect;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = GlassmorphismTheme.radiusLarge,
    this.blurAmount = GlassmorphismTheme.blurAmount,
    this.backgroundColor,
    this.elevated = false,
    this.animateEntrance = true,
    this.entranceDelay = Duration.zero,
    this.hoverEffect = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animateEntrance) {
      if (widget.entranceDelay == Duration.zero) {
        _entranceController.forward();
      } else {
        Future.delayed(widget.entranceDelay, () {
          if (mounted) _entranceController.forward();
        });
      }
    } else {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: widget.width,
            height: widget.height,
            margin: widget.margin ?? const EdgeInsets.all(8),
            transform: (widget.hoverEffect && _isHovered) 
                ? (Matrix4.identity()..scale(1.02)) 
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: _isHovered 
                      ? GlassmorphismTheme.primaryRed.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.05),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: widget.blurAmount, sigmaY: widget.blurAmount),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? Colors.white.withOpacity(_isHovered ? 0.85 : 0.72),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: _isHovered 
                          ? GlassmorphismTheme.primaryRed.withOpacity(0.3) 
                          : Colors.white.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
