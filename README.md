# Wi-Fi Room Mapper

An advanced indoor localization, Wi-Fi fingerprinting, and spatial surveying application built with Flutter.

Wi-Fi Room Mapper enables high-precision campus and building mapping using 802.11 Wi-Fi RSSI signals, multi-pass observation sampling, and a boundary-aware indoor localization prediction engine.

---

## Key Features

### 📡 Multi-Pass Wi-Fi Fingerprinting
- **Burst Sampling**: Capture multi-pass scan sessions with configurable pass counts (e.g., 5 passes) and inter-scan delay intervals (e.g., 3 seconds) to account for transient multipath fading and temporal RSSI fluctuations.
- **Sub-Location Position Tagging**: Tag observations by physical location within each space (`Center`, `Entry`, `Window`, `Wall L`, `Wall R`, `Corridor`).
- **Android Throttling Resilience**: Graceful fallbacks and countdown timers to respect the Android 4-scans-per-2-minutes foreground throttling limit.

### 🏛️ Customizable 4-Tier Taxonomy
- **Flexible Hierarchy**: Adapt the naming schema to match any organizational structure (Default: `Site` → `Block` → `Level` → `Space`; e.g., *IIIT Nagpur* → *Hostel Block A* → *Floor 4* → *443*).
- **Custom Sampling Labels**: Add or reorder sampling position tags to suit specific floorplans.

### 🧠 Boundary-Aware Prediction Engine
- **Multi-Gate Classification**:
  - **Gate A (Outside / Unmapped Rejection)**: Filters out weak or foreign signals when standing outside recorded areas (cosine < 0.72 or RMSE > 10.5 dB).
  - **Gate B (Corridor / Hallway Detection)**: Detects when the user is standing in a mapped hallway or outside classroom doors.
  - **Gate C (Shared Wall Boundary)**: Flags when the user is standing near a shared partition wall between two adjacent spaces where signals are too close to call without overfitting ($\Delta \text{RMSE} < 1.8\text{ dB}$, $\Delta \text{Cosine} < 0.035$).
  - **Gate D (Confident Inside Match)**: Identifies the exact room and closest sub-location with high confidence.
- **5GHz Band Weighting**: Applies higher weight ($1.6\times$ for 5GHz, $1.8\times$ for 6GHz) to higher-frequency access points because 5GHz signals attenuate sharply across brick and concrete walls ($12\text{--}18\text{ dB}$ loss), minimizing wall-bleed errors.
- **Blended Distance Metric**: Evaluates similarity using 60% closest sub-location snapshot RMSE + 40% room centroid RMSE so users standing near walls aren't penalized.
- **k-NN Voting**: Validates predictions using $k$-nearest neighbors across individual observation snapshots.

### 🎨 Uber-Inspired High-Contrast Design
- **OLED Dark & Light Themes**: Pure `#000000` dark mode and `#FFFFFF` light mode with 1px hairline dividers, tabular mono figures, and clean typography.
- **SignalColors Theme Extension**: Semantic color tokens for signal quality (Excellent, Good, Fair, Weak) and frequency bands (2.4GHz, 5GHz, 6GHz).

### 💾 Data Persistence & Portability
- **Local Persistence**: Automated storage via `SharedPreferences`.
- **JSON Backup & Restore**: Full JSON schema export and intelligent merge-restore without overwriting existing sessions.
- **Machine Learning CSV Export**: Export flat tabular datasets with one row per scan snapshot for offline training in Python (pandas, scikit-learn, TensorFlow).
- **Bulk Space Management**: Multi-select spaces for batch deletion or seamless session merging.

---

## Prediction Algorithm Formulation

### 1. Frequency Band Attenuation Weighting
$$w(\text{freq}) = \begin{cases} 1.8 & \text{if } \text{freq} \ge 5925\text{ MHz (6 GHz)} \\ 1.6 & \text{if } \text{freq} \ge 4900\text{ MHz (5 GHz)} \\ 1.0 & \text{otherwise (2.4 GHz)} \end{cases}$$

### 2. Weighted Cosine Similarity
$$\text{Cosine}(L, R) = \frac{\sum_{i} w_i \cdot \hat{L}_i \cdot \hat{R}_i}{\sqrt{\sum_{i} w_i \hat{L}_i^2} \cdot \sqrt{\sum_{i} w_i \hat{R}_i^2}}$$
Where $\hat{X}_i = \text{clamp}(X_i + 90, 0, 60)$ transforms negative dBm signals into non-negative similarity vectors.

### 3. Effective Blended RMSE
$$\text{RMSE}_{\text{eff}} = 0.6 \cdot \text{RMSE}_{\text{closest\_snapshot}} + 0.4 \cdot \text{RMSE}_{\text{room\_centroid}}$$

---

## Project Structure

```
lib/
├── logic/
│   ├── fingerprint_stats.dart  # BSSID statistics, mean/median/variance & quality score
│   ├── room_predictor.dart     # Boundary-aware prediction engine with Gates A-D
│   └── storage_export.dart     # SharedPreferences persistence, JSON & CSV export
├── models/
│   └── room_models.dart        # ApReading, ScanSnapshot, ScanSession, RoomRecord
├── tabs/
│   ├── analysis_tab.dart       # Verify & Locate tab, stability inspection, AP overlap
│   ├── home_tab.dart           # Dashboard overview with bento metric cards
│   ├── rooms_tab.dart          # Spaces hierarchy browser, bulk selection & merge
│   ├── scan_tab.dart           # Live Wi-Fi scanner, multi-pass session recorder
│   └── settings_tab.dart       # Taxonomy labels, custom positions & backups
├── theme/
│   └── app_theme.dart          # Uber Base dark/light theme & SignalColors extension
├── widgets/
│   ├── animated_card.dart      # Micro-interactions & staggered entry animations
│   ├── detail_sheets.dart      # Access point inspector & session history bottom sheets
│   └── signal_bar.dart         # RSSI strength meter & dBm badge
└── main.dart                   # Main application shell, state & navigation wiring
```

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.13.4` or higher
- Android SDK with Wi-Fi & Location permissions enabled

### Required Android Permissions
The following permissions are configured in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Running the App
```bash
flutter pub get
flutter run
```

### Running Tests
Execute the full test suite including unit tests and responsive widget verification:
```bash
flutter test
```
