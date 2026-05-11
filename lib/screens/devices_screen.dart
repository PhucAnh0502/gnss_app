import 'dart:io';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/providers/device_provider.dart';
import 'package:gnss_app/screens/history_screen.dart';
import 'package:gnss_app/screens/map_screen.dart';
import 'package:gnss_app/screens/scan_device_qr_screen.dart';
import 'package:gnss_app/utils/app_snackbar.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddDeviceDialog() async {
    _nameController.clear();
    _codeController.clear();
    final androidId = await _resolveAndroidId();
    if (androidId.isNotEmpty) {
      _codeController.text = androidId;
    }
    final screenContext = context;
    var isBusy = false;

    await showDialog<void>(
      context: screenContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16243A),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.slate400.withValues(alpha: 0.14),
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline, color: AppColors.brandBlue),
                  SizedBox(width: 10),
                  Text(
                    'Add New Device',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Device Name',
                        hintText: 'GNSS Tracker A1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: 'Device Code',
                        hintText: 'ABC-123-XYZ',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () async {
                            final raw = await Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (_) => const ScanDeviceQrScreen(),
                              ),
                            );
                            if (raw == null || raw.trim().isEmpty || !mounted) {
                              return;
                            }
                            final parsedCode = _extractDeviceCode(raw);
                            setState(() {
                              _codeController.text = parsedCode;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tip: QR can contain plain code, JSON {"deviceCode":"..."}, or URL query ?deviceCode=...',
                        style: TextStyle(fontSize: 12, color: AppColors.slate400),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.slate400,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          setDialogState(() {
                            isBusy = true;
                          });
                          final name = _nameController.text.trim();
                          final code = _codeController.text.trim();

                          if (name.isEmpty || code.isEmpty) {
                            setDialogState(() {
                              isBusy = false;
                            });
                            AppSnackBar.error(
                              screenContext,
                              'Device name and device code are required.',
                            );
                            return;
                          }

                          try {
                            await ref
                                .read(deviceActionProvider.notifier)
                                .addDevice(name, code);

                            if (!mounted) {
                              return;
                            }

                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                            AppSnackBar.success(
                              screenContext,
                              'Device added successfully.',
                            );
                          } catch (error) {
                            AppSnackBar.error(
                              screenContext,
                              _friendlyError(error),
                            );
                            if (mounted) {
                              setDialogState(() {
                                isBusy = false;
                              });
                            }
                            return;
                          }
                        },
                  child: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Device'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _resolveAndroidId() async {
    if (!Platform.isAndroid) {
      return '';
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.id.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _showEditDialog(DeviceModel device) async {
    final editController = TextEditingController(text: device.deviceName);
    final screenContext = context;
    var isBusy = false;
    await showDialog<void>(
      context: screenContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16243A),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.slate400.withValues(alpha: 0.14),
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                children: const [
                  Icon(Icons.edit_outlined, color: AppColors.brandBlue),
                  SizedBox(width: 10),
                  Text(
                    'Rename Device',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: TextField(
                controller: editController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'Enter a new device name',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.slate400,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          setDialogState(() {
                            isBusy = true;
                          });

                          final newName = editController.text.trim();
                          if (newName.isEmpty) {
                            setDialogState(() {
                              isBusy = false;
                            });
                            AppSnackBar.error(
                              screenContext,
                              'Device name cannot be empty.',
                            );
                            return;
                          }

                          try {
                            await ref
                                .read(deviceActionProvider.notifier)
                                .updateDevice(device.id, newName);

                            if (!mounted) {
                              return;
                            }

                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                            AppSnackBar.success(
                              screenContext,
                              'Device updated successfully.',
                            );
                          } catch (error) {
                            AppSnackBar.error(
                              screenContext,
                              _friendlyError(error),
                            );
                            if (mounted) {
                              setDialogState(() {
                                isBusy = false;
                              });
                            }
                            return;
                          }
                        },
                  child: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    editController.dispose();
  }

  Future<void> _confirmDelete(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16243A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.red.shade400.withValues(alpha: 0.22),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade300),
            const SizedBox(width: 10),
            const Text(
              'Delete Device',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Delete ${device.deviceName}? This action cannot be undone.',
          style: const TextStyle(
            color: AppColors.slate400,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.slate400,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(deviceActionProvider.notifier).deleteDevice(device.id);
    if (!mounted) {
      return;
    }
    final actionState = ref.read(deviceActionProvider);
    if (actionState.hasError) {
      AppSnackBar.error(context, _friendlyError(actionState.error));
      return;
    }

    AppSnackBar.success(context, 'Device deleted successfully.');
  }

  String _friendlyError(Object? error) {
    if (error == null) {
      return 'Operation failed. Please try again.';
    }
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  String _extractDeviceCode(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      return raw;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final byDeviceCode = decoded['deviceCode']?.toString().trim();
        if (byDeviceCode != null && byDeviceCode.isNotEmpty) {
          return byDeviceCode;
        }

        final byCode = decoded['code']?.toString().trim();
        if (byCode != null && byCode.isNotEmpty) {
          return byCode;
        }

        final bySnakeCase = decoded['device_code']?.toString().trim();
        if (bySnakeCase != null && bySnakeCase.isNotEmpty) {
          return bySnakeCase;
        }
      }
    } catch (_) {
      // Ignore non-JSON QR payloads.
    }

    final asUri = Uri.tryParse(raw);
    if (asUri != null && asUri.queryParameters.isNotEmpty) {
      final fromQuery =
          asUri.queryParameters['deviceCode'] ?? asUri.queryParameters['code'];
      if (fromQuery != null && fromQuery.trim().isNotEmpty) {
        return fromQuery.trim();
      }
    }

    return raw;
  }

  String _resolvedStatus(DeviceModel device) {
    return device.status.trim().toLowerCase();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade400;
      case 'inactive':
      default:
        return AppColors.slate400;
    }
  }

  String _formatLastPing(DeviceModel device) {
    final lastPing = device.lastPing;
    if (lastPing == null) {
      return 'Last ping: never';
    }

    final age = DateTime.now().difference(lastPing.toLocal());
    if (age.inSeconds < 60) {
      return 'Last ping: ${age.inSeconds}s ago';
    }
    if (age.inMinutes < 60) {
      return 'Last ping: ${age.inMinutes}m ago';
    }
    if (age.inHours < 24) {
      return 'Last ping: ${age.inHours}h ago';
    }

    return 'Last ping: ${lastPing.toLocal()}';
  }

  bool _matchesStatusFilter(DeviceModel device, String filter) {
    final status = _resolvedStatus(device);
    switch (filter) {
      case 'active':
        return status == 'active';
      case 'inactive':
        return status == 'inactive';
      case 'all':
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(realtimeDevicesProvider);
    final actionState = ref.watch(deviceActionProvider);
    final allDevices = devicesAsync.maybeWhen(
      data: (devices) => devices,
      orElse: () => const <DeviceModel>[],
    );
    final totalCount = allDevices.length;
    final activeCount =
      allDevices.where((d) => _matchesStatusFilter(d, 'active')).length;
    final inactiveCount =
      allDevices.where((d) => _matchesStatusFilter(d, 'inactive')).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Devices',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalCount total · $activeCount active',
                    style: const TextStyle(
                      color: AppColors.slate400,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandBlue,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: actionState.isLoading ? null : _openAddDeviceDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Add device',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1E2F4B),
              border: Border.all(
                color: AppColors.slate400.withValues(alpha: 0.18),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: AppColors.textLight, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: AppColors.slate400),
                hintText: 'Search by name or IMEI...',
                hintStyle: TextStyle(color: AppColors.slate400, fontSize: 16),
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DeviceFilterChip(
                  label: 'All ($totalCount)',
                  selected: _selectedStatusFilter == 'all',
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = 'all';
                    });
                  },
                ),
                const SizedBox(width: 10),
                _DeviceFilterChip(
                  label: 'Active ($activeCount)',
                  selected: _selectedStatusFilter == 'active',
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = 'active';
                    });
                  },
                ),
                const SizedBox(width: 10),
                _DeviceFilterChip(
                  label: 'Inactive ($inactiveCount)',
                  selected: _selectedStatusFilter == 'inactive',
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = 'inactive';
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: devicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _friendlyError(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(realtimeDevicesProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (devices) {
                final filteredDevices = devices.where((device) {
                  if (!_matchesStatusFilter(device, _selectedStatusFilter)) {
                    return false;
                  }
                  if (_searchQuery.isEmpty) {
                    return true;
                  }
                  final name = device.deviceName.toLowerCase();
                  final code = device.deviceCode.toLowerCase();
                  return name.contains(_searchQuery) || code.contains(_searchQuery);
                }).toList();

                if (filteredDevices.isEmpty) {
                  return Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.bgSidebar.withValues(alpha: 0.72),
                        border: Border.all(
                          color: AppColors.slate400.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.devices_other, size: 42, color: AppColors.slate400),
                          SizedBox(height: 12),
                          Text(
                            'No devices found for this search.',
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(realtimeDevicesProvider);
                    // Wait for stream to emit new value
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredDevices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final device = filteredDevices[index];
                      final status = _resolvedStatus(device);
                      final statusColor = _statusColor(status);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.bgSidebar.withValues(alpha: 0.9),
                          border: Border.all(
                            color: AppColors.slate400.withValues(alpha: 0.16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: AppColors.brandBlue.withValues(alpha: 0.05),
                              blurRadius: 22,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device.deviceName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Device options',
                                  icon: const Icon(
                                    Icons.more_horiz,
                                    color: AppColors.slate400,
                                  ),
                                  color: const Color(0xFF152238),
                                  surfaceTintColor: Colors.transparent,
                                  elevation: 14,
                                  menuPadding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: AppColors.slate400.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'map') {
                                      ref.read(selectedDeviceProvider.notifier).state = device;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const MapScreen(),
                                        ),
                                      );
                                    } else if (value == 'history') {
                                      ref.read(selectedDeviceProvider.notifier).state = device;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const HistoryScreen(),
                                        ),
                                      );
                                    } else if (value == 'rename') {
                                      _showEditDialog(device);
                                    } else if (value == 'delete') {
                                      _confirmDelete(device);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'map',
                                      height: 42,
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.map_outlined,
                                            size: 20,
                                            color: AppColors.brandBlue,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'View on Map',
                                            style: TextStyle(
                                              color: AppColors.textLight,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'history',
                                      height: 42,
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.history,
                                            size: 20,
                                            color: AppColors.brandBlue,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'View History',
                                            style: TextStyle(
                                              color: AppColors.textLight,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'rename',
                                      height: 42,
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: AppColors.brandBlue,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Rename Device',
                                            style: TextStyle(
                                              color: AppColors.textLight,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(height: 10),
                                    PopupMenuItem(
                                      value: 'delete',
                                      height: 42,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.red.shade400,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Remove Device',
                                            style: TextStyle(
                                              color: Colors.red.shade400,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Code: ${device.deviceCode}',
                              style: const TextStyle(color: AppColors.slate400),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                  ),
                                ),
                                Text(
                                  'Status: ${_statusLabel(status)}',
                                  style: const TextStyle(color: AppColors.slate400),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatLastPing(device),
                              style: const TextStyle(color: AppColors.slate400),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceFilterChip extends StatelessWidget {
  const _DeviceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlue : const Color(0xFF1A2A44),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.brandBlue.withValues(alpha: 0.9)
                : AppColors.slate400.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.slate400,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
