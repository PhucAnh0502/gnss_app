import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gnss_app/constants/app_colors.dart';

/// Result from the DateTimePickerSheet.
class DateTimeRange {
  final DateTime from;
  final DateTime to;
  const DateTimeRange({required this.from, required this.to});
}

/// A full bottom sheet with two modes:
/// - Relative: quick range selection (1h, 6h, 1d, 3d, 7d, 30d)
/// - Absolute: separate pages for From and To, each with calendar + time spinner
class DateTimePickerSheet extends StatefulWidget {
  const DateTimePickerSheet({
    super.key,
    required this.initialFrom,
    required this.initialTo,
  });

  final DateTime initialFrom;
  final DateTime initialTo;

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTime initialFrom,
    required DateTime initialTo,
  }) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateTimePickerSheet(initialFrom: initialFrom, initialTo: initialTo),
    );
  }

  @override
  State<DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<DateTimePickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _from;
  late DateTime _to;

  final PageController _pageController = PageController();
  int _absolutePage = 0;

  // Keys for the date-time pages to access their current value
  final GlobalKey<_DateTimePageState> _fromPageKey = GlobalKey();
  final GlobalKey<_DateTimePageState> _toPageKey = GlobalKey();

  static const _relativeOptions = [
    _RelativeOption('1 hour', Duration(hours: 1)),
    _RelativeOption('6 hours', Duration(hours: 6)),
    _RelativeOption('12 hours', Duration(hours: 12)),
    _RelativeOption('1 day', Duration(days: 1)),
    _RelativeOption('3 days', Duration(days: 3)),
    _RelativeOption('7 days', Duration(days: 7)),
    _RelativeOption('14 days', Duration(days: 14)),
    _RelativeOption('30 days', Duration(days: 30)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _from = widget.initialFrom.toLocal();
    _to = widget.initialTo.toLocal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _applyRelative(Duration duration) {
    setState(() {
      _to = DateTime.now();
      _from = _to.subtract(duration);
    });
  }

  void _apply() {
    // Read latest values from pages (in case user is on absolute tab)
    final fromVal = _fromPageKey.currentState?.dateTime ?? _from;
    final toVal = _toPageKey.currentState?.dateTime ?? _to;
    Navigator.pop(context, DateTimeRange(from: fromVal, to: toVal));
  }

  void _goToAbsolutePage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _syncFromPage(DateTime dt) {
    _from = dt;
    // Only update header preview, don't rebuild pages
    setState(() {});
  }

  void _syncToPage(DateTime dt) {
    _to = dt;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: Container(
        height: screenHeight * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF080F1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.slate400.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded, size: 20, color: AppColors.brandBlue),
                  const SizedBox(width: 10),
                  const Text('Select time range', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.2)),
                    ),
                    child: Text(_formatRangePreview(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.brandBlueLight, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1730),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.3)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                labelColor: AppColors.brandBlueLight,
                unselectedLabelColor: AppColors.slate400,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [Tab(text: 'Relative'), Tab(text: 'Absolute')],
              ),
            ),
            const SizedBox(height: 14),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRelativeTab(),
                  _buildAbsoluteTab(),
                ],
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate700.withValues(alpha: 0.3)))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.slate300,
                        side: BorderSide(color: AppColors.slate700.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Apply'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== RELATIVE TAB =====
  Widget _buildRelativeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a relative time range', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _relativeOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final option = _relativeOptions[index];
                final isSelected = _isRelativeMatch(option.duration);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _applyRelative(option.duration),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.1) : const Color(0xFF0D1730),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.4) : AppColors.slate700.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: isSelected ? AppColors.brandBlue : AppColors.slate500),
                          const SizedBox(width: 12),
                          Text('Last ${option.label}', style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? AppColors.textLight : AppColors.slate300)),
                          const Spacer(),
                          if (isSelected) const Icon(Icons.check_circle, size: 18, color: AppColors.brandBlue),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isRelativeMatch(Duration duration) {
    final diff = _to.difference(_from);
    return (diff.inMinutes - duration.inMinutes).abs() < 2;
  }

  // ===== ABSOLUTE TAB =====
  Widget _buildAbsoluteTab() {
    return Column(
      children: [
        // From / To tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _PageTab(
                  label: 'From',
                  subtitle: _formatShort(_from),
                  isActive: _absolutePage == 0,
                  onTap: () => _goToAbsolutePage(0),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.slate500),
              ),
              Expanded(
                child: _PageTab(
                  label: 'To',
                  subtitle: _formatShort(_to),
                  isActive: _absolutePage == 1,
                  onTap: () => _goToAbsolutePage(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Pages
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _absolutePage = page),
            physics: const BouncingScrollPhysics(),
            children: [
              _DateTimePage(
                key: _fromPageKey,
                initialDateTime: _from,
                onChanged: _syncFromPage,
              ),
              _DateTimePage(
                key: _toPageKey,
                initialDateTime: _to,
                onChanged: _syncToPage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatShort(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatRangePreview() {
    return '${_formatShort(_from)} \u2192 ${_formatShort(_to)}';
  }
}

// ===== DATE TIME PAGE (stateful, keeps alive) =====
class _DateTimePage extends StatefulWidget {
  const _DateTimePage({
    super.key,
    required this.initialDateTime,
    required this.onChanged,
  });

  final DateTime initialDateTime;
  final ValueChanged<DateTime> onChanged;

  @override
  _DateTimePageState createState() => _DateTimePageState();
}

class _DateTimePageState extends State<_DateTimePage> with AutomaticKeepAliveClientMixin {
  late DateTime dateTime;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    dateTime = widget.initialDateTime;
    _hourController = FixedExtentScrollController(initialItem: dateTime.hour);
    _minuteController = FixedExtentScrollController(initialItem: dateTime.minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _updateDate(DateTime newDate) {
    setState(() {
      dateTime = DateTime(newDate.year, newDate.month, newDate.day, dateTime.hour, dateTime.minute);
    });
    widget.onChanged(dateTime);
  }

  void _updateHour(int hour) {
    setState(() {
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, hour, dateTime.minute);
    });
    widget.onChanged(dateTime);
  }

  void _updateMinute(int minute) {
    setState(() {
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour, minute);
    });
    widget.onChanged(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Calendar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1730),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700.withValues(alpha: 0.25)),
            ),
            child: Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.brandBlue,
                  onPrimary: Colors.white,
                  surface: Color(0xFF0D1730),
                  onSurface: AppColors.textLight,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: dateTime,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                onDateChanged: _updateDate,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Time picker
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1730),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate700.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.brandBlueLight),
                    const SizedBox(width: 8),
                    const Text('Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate300)),
                    const Spacer(),
                    Text(
                      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textLight, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSpinner(_hourController, 23, _updateHour),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.slate400)),
                      ),
                      Expanded(
                        child: _buildSpinner(_minuteController, 59, _updateMinute),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSpinner(FixedExtentScrollController controller, int max, ValueChanged<int> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF081220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3)),
      ),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 34,
        diameterRatio: 1.2,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.brandBlue.withValues(alpha: 0.3), width: 1),
            ),
          ),
        ),
        onSelectedItemChanged: onChanged,
        children: List.generate(max + 1, (i) {
          return Center(
            child: Text(
              i.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textLight, fontFamily: 'monospace'),
            ),
          );
        }),
      ),
    );
  }
}

// ===== PAGE TAB =====
class _PageTab extends StatelessWidget {
  const _PageTab({required this.label, required this.subtitle, required this.isActive, required this.onTap});

  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandBlue.withValues(alpha: 0.12) : const Color(0xFF0D1730),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? AppColors.brandBlue.withValues(alpha: 0.4) : AppColors.slate700.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? AppColors.brandBlueLight : AppColors.slate400)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.textLight : AppColors.slate500, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelativeOption {
  final String label;
  final Duration duration;
  const _RelativeOption(this.label, this.duration);
}
