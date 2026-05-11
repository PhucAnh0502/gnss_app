import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanDeviceQrScreen extends StatefulWidget {
  const ScanDeviceQrScreen({super.key});

  static const routeName = '/scan-device-qr';

  @override
  State<ScanDeviceQrScreen> createState() => _ScanDeviceQrScreenState();
}

class _ScanDeviceQrScreenState extends State<ScanDeviceQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    torchEnabled: false,
  );

  bool _handled = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    final raw =
      capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue?.trim() : null;
    if (raw == null || raw.isEmpty) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Device QR'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white70, width: 2),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) {
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      }
                    },
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    ),
                    label: const Text('Flash'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
