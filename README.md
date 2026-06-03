# GNSS Vision — Mobile App

Ứng dụng Flutter thu thập dữ liệu GNSS raw, tracking vị trí real-time qua MQTT, và tự động chụp ảnh gắn metadata GPS.

## Tech Stack

- **Flutter 3.x** (Dart 3.9+)
- **Riverpod** — state management
- **Dio** — HTTP client
- **MQTT Client** — publish tracking data real-time
- **Geolocator** — GPS position stream
- **Raw GNSS 2025** — satellite measurements, status, clock
- **Flutter Compass** — magnetometer heading
- **Camera** — auto-capture photos
- **Flutter Background Service** — background tracking
- **Flutter Map + LatLong2** — bản đồ offline/online
- **Socket.IO Client** — nhận live data từ server
- **Shared Preferences** — local settings persistence
- **Cached Network Image** — thumbnail caching

## Cấu trúc thư mục

```
lib/
├── background/       # Background service handlers
├── constants/        # Colors, environment config
├── models/           # Data models (Device, Snapshot, Tracking)
├── providers/        # Riverpod state management
│   ├── tracking_provider.dart    # GNSS + MQTT lifecycle
│   ├── auto_capture_provider.dart # Auto-capture config
│   ├── snapshot_provider.dart    # Snapshot CRUD
│   └── device_provider.dart      # Device list
├── screens/          # UI screens
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── snapshots_screen.dart
│   └── settings_screen.dart
├── services/         # Business logic
│   ├── gnss_service.dart              # GPS + satellite streams
│   ├── mqtt_service.dart              # MQTT publish
│   ├── auto_capture_service.dart      # Timer/distance capture logic
│   ├── auto_capture_foreground_service.dart  # Camera foreground service
│   ├── snapshot_service.dart          # Snapshot API calls
│   ├── api_service.dart               # Dio instance
│   └── tracking_background_service.dart # Background service
├── utils/            # Helpers
├── widgets/          # Reusable widgets
│   ├── auto_capture_settings.dart
│   ├── snapshot_detail_modal.dart
│   └── ...
└── main.dart         # Entry point
```

## Chức năng chính

### GNSS Tracking
- Thu thập vị trí GPS với Geolocator (1 Hz)
- Đọc raw GNSS: satellite status (SVID, constellation, C/N0, usedInFix), measurements, clock
- Sensor fusion: GPS bearing + compass heading (theo tốc độ)
- Speed smoothing + dead zone filter
- Publish data qua MQTT tới broker → backend lưu DB + emit WebSocket

### Auto Capture
- Tự động chụp ảnh camera khi tracking đang chạy
- 2 mode: **Timer** (mỗi N giây) hoặc **Distance** (mỗi N mét)
- Metadata GPS (lat, lng, hdop, satellites, speed) gắn vào mỗi ảnh
- Upload lên server (init snapshot → upload file)
- Cấu hình quality (low/medium/high)
- Device ID tự động lấy từ thiết bị Android

### Background Service
- Foreground service Android (notification persistent)
- Tiếp tục tracking + capture khi app minimized
- Auto-start khi bật lại app nếu tracking đã enabled

### Live Map
- Hiển thị vị trí hiện tại trên Flutter Map
- Polyline tracking path
- Satellite sky view

## Cài đặt & Chạy

```bash
# Cài dependencies
flutter pub get

# Tạo file .env (root của gnss_app/)
# BASE_API_URL=http://10.0.2.2:5000/api
# MQTT_BROKER_URL=mqtt://your-broker:1883
# MQTT_TOPIC_PATTERN=gnss/{deviceCode}

# Chạy debug
flutter run

# Build APK release
flutter build apk --release
```

## Biến môi trường (.env)

| Biến | Mô tả |
|------|--------|
| `BASE_API_URL` | Backend API URL |
| `MQTT_BROKER_URL` | MQTT broker URL |
| `MQTT_TOPIC_PATTERN` | Topic pattern (vd: `gnss/{deviceCode}`) |

## Quyền Android

- `ACCESS_FINE_LOCATION` — GPS
- `ACCESS_BACKGROUND_LOCATION` — tracking background
- `CAMERA` — auto-capture
- `FOREGROUND_SERVICE` — background service
- `FOREGROUND_SERVICE_LOCATION` — location service type
- `FOREGROUND_SERVICE_CAMERA` — camera service type
- `POST_NOTIFICATIONS` — notification khi tracking chạy
- `INTERNET` — network access
- `WAKE_LOCK` — keep CPU alive

## Luồng hoạt động chính

```
User bật Tracking
  → Request permissions (location, camera, notification)
  → Start GnssService (GPS + satellite + compass streams)
  → Start MQTT connection → publish to broker mỗi giây
  → Start AutoCaptureForegroundService
    → Đọc config từ SharedPreferences
    → Timer/Distance trigger → take photo → init snapshot → upload
  → Background service giữ tracking khi minimize app
```
