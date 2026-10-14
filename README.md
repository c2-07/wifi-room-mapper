# Wi-Fi Room Mapper

A Flutter app for mapping indoor spaces using Wi-Fi signal fingerprints and predicting room locations.

## Features

- **Wi-Fi Scanning:** Capture multiple scans per location with configurable intervals.
- **Location Tagging:** Label scans by position, such as Center, Entry, Window, and Walls.
- **Room Hierarchy:** Organize spaces by Site → Block → Level → Space, with customizable labels.
- **Room Prediction:** Identify rooms, detect corridors, reject unknown locations, and flag ambiguous boundaries.
- **Signal Analysis:** Compare RSSI fingerprints using weighted cosine similarity, RMSE, and k-NN.
- **Frequency Weighting:** Apply different weights to 2.4 GHz, 5 GHz, and 6 GHz access points.
- **Themes:** OLED dark and light modes with signal strength indicators.
- **Data Management:** Local storage, JSON backup and restore, CSV export, bulk deletion, and session merging.

## Prediction Algorithm

- **Frequency weights:** 2.4 GHz = 1.0, 5 GHz = 1.6, 6 GHz = 1.8.
- **Similarity:** Weighted cosine similarity between Wi-Fi fingerprints.
- **Distance:** Combine the closest snapshot RMSE (60%) and room centroid RMSE (40%).
- **Classification:** Use thresholds and k-NN voting to distinguish rooms, corridors, boundaries, and unmapped areas.

## Project Structure

```text
lib/
├── logic/
│   ├── fingerprint_stats.dart
│   ├── room_predictor.dart
│   └── storage_export.dart
├── models/
│   └── room_models.dart
├── tabs/
│   ├── home_tab.dart
│   ├── scan_tab.dart
│   ├── rooms_tab.dart
│   ├── analysis_tab.dart
│   └── settings_tab.dart
├── theme/
│   └── app_theme.dart
├── widgets/
│   ├── animated_card.dart
│   ├── detail_sheets.dart
│   └── signal_bar.dart
└── main.dart
```

## Requirements

- Flutter SDK 3.13.4 or later
- Android SDK and required Wi-Fi and location permissions

## Run

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter test
```
