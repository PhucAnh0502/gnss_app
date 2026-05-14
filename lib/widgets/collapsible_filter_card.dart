import 'package:flutter/material.dart';
import 'package:gnss_app/constants/app_colors.dart';

/// A collapsible card that shows a compact summary when closed
/// and expands to reveal full filter content with smooth animation.
class CollapsibleFilterCard extends StatefulWidget {
  const CollapsibleFilterCard({
    super.key,
    required this.title,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
  });

  /// Title shown in the header (e.g. "Filters")
  final String title;

  /// Summary text shown when collapsed (e.g. "7d · Device A")
  final String summary;

  /// The full filter content shown when expanded
  final Widget child;

  /// Whether the card starts expanded
  final bool initiallyExpanded;

  @override
  State<CollapsibleFilterCard> createState() => _CollapsibleFilterCardState();
}

class _CollapsibleFilterCardState extends State<CollapsibleFilterCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
        reverseCurve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.bgSidebar.withValues(alpha: 0.72),
        border: Border.all(
          color: _isExpanded
              ? AppColors.brandBlue.withValues(alpha: 0.15)
              : AppColors.slate400.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (always visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.brandBlue),
                    ),
                    const SizedBox(width: 12),
                    // Title + summary
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textLight),
                          ),
                          // Summary (fades out when expanded)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.summary,
                                style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chevron
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
