import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/snapshot_model.dart';
import 'package:latlong2/latlong.dart';

class SnapshotDetailModal extends StatelessWidget {
  const SnapshotDetailModal({super.key, required this.snapshot});

  final SnapshotModel snapshot;

  @override
  Widget build(BuildContext context) {
    final hasLocation = snapshot.latitude != null && snapshot.longitude != null;
    final imageWidget = _buildImageWidget(context);

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.65,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF07111F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate400.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.photo_camera, color: AppColors.brandBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Snapshot ${snapshot.id.substring(0, 8)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textLight),
                        ),
                      ),
                      _StatusChip(status: snapshot.syncStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 260,
                      width: double.infinity,
                      color: AppColors.bgSidebar,
                      child: imageWidget,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgSidebar,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.slate400.withValues(alpha: 0.14)),
                    ),
                    child: hasLocation
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(snapshot.latitude!, snapshot.longitude!),
                                initialZoom: 16,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'gnss_app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(snapshot.latitude!, snapshot.longitude!),
                                      width: 36,
                                      height: 36,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.brandBlue,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.place, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: Text('No location available for this snapshot', style: TextStyle(color: AppColors.slate400)),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _MetadataTile(label: 'Captured', value: snapshot.capturedAt.toLocal().toString()),
                  _MetadataTile(label: 'Location', value: hasLocation ? '${snapshot.latitude}, ${snapshot.longitude}' : '-'),
                  _MetadataTile(label: 'Altitude', value: snapshot.altitude.toStringAsFixed(2)),
                  _MetadataTile(label: 'Speed', value: '${snapshot.speed.toStringAsFixed(1)} km/h'),
                  _MetadataTile(label: 'Heading', value: snapshot.heading.toStringAsFixed(1)),
                  _MetadataTile(label: 'HDOP', value: snapshot.hdop.toStringAsFixed(2)),
                  _MetadataTile(label: 'Satellites', value: '${snapshot.satellitesUsed}/${snapshot.satellitesCount}'),
                  if ((snapshot.note ?? '').isNotEmpty) _MetadataTile(label: 'Note', value: snapshot.note!),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context) {
    if (snapshot.imageUrl != null && snapshot.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: snapshot.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, _, __) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.slate400, size: 42),
        ),
      );
    }

    return Container(
      color: AppColors.bgSidebar,
      child: const Center(
        child: Icon(Icons.photo_size_select_actual_outlined, color: AppColors.slate400, size: 42),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'synced'
        ? Colors.green.shade400
        : normalized == 'failed'
            ? Colors.red.shade400
            : normalized == 'uploaded'
                ? Colors.blue.shade400
                : AppColors.slate400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _MetadataTile extends StatelessWidget {
  const _MetadataTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSidebar.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}