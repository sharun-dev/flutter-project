# TravelMate 🚌✈️

TravelMate is a comprehensive agency booking and administrative dashboard application built with Flutter. Located within the `trailer/` module of this repository, it serves as a powerful ecosystem for travel agencies to manage fleet details, handle bookings, track real-time communication, and moderate platform activity.

## 🚀 Key Features

* **Agency Dashboard:** A centralized control panel for travel agencies to monitor active buses, handle booking schedules, and visualize agency metrics via interactive charts.
* **Bus Management & Scheduling:** Dedicated bus details interface featuring an availability booking calendar (`Table Calendar`) and structured scheduling logic.
* **Admin & Moderation Panel:** Robust admin workflows designed for user/agency verification, content moderation, and system report handling.
* **Real-Time Communication:** Integrated chat architecture featuring real-time messaging, status badges, and message deletion support.
* **Optimized Media Delivery:** Seamless upload pipelines for verification documents and agency images directly to the Cloudinary CDN.
* **Secure Environment Architecture:** Utilizes local `.env` configuration mapping via `flutter_dotenv` to abstract API keys and secrets away from production builds.

---

## 🛠️ Tech Stack & Architecture

* **Frontend Framework:** Flutter & Dart (Targeting multi-platform environments)
* **State Management:** Provider Architecture
* **Backend Ecosystem:** Firebase Core, Firebase Auth, Cloud Firestore, and Firebase Cloud Storage
* **Media & Cloud Storage:** Cloudinary integration for lightning-fast asset delivery
* **Libraries Used:** Table Calendar, Flutter Dotenv, Charts, File Picker, Image Picker, URL Launcher
* **Development Accelerator:** Developed with the support of GitHub Copilot to optimize architectural efficiency and speed up coding workflows.

---

## ⚙️ Steps to Run TravelMate in VS Code

To launch and test the **TravelMate** application locally, ensure you have the Flutter SDK (`>=3.7.2` for this module) installed, and follow this configuration workflow:

<Sequence>
  <Step subtitle="Step 1" title="Navigate to the Module Directory">
    Open your project terminal in VS Code and change directories into the TravelMate subfolder:
```bash
    cd trailer
    ```
  </Step>
  <Step subtitle="Step 2" title="Fetch Module Dependencies">
    Execute the package manager command to download all specified package versions required for the dashboard:
```bash
    flutter pub get
    ```
  </Step>
  <Step subtitle="Step 3" title="Inject Local Configurations">
    Because sensitive credentials are kept out of source control, manually place your Firebase config maps (`firebase_options.dart`, `google-services.json`, or `GoogleService-Info.plist`) inside the corresponding native folders under `trailer/`.
  </Step>
  <Step subtitle="Step 4" title="Configure Cloudinary Environment Variables">
    Create a local configuration file at `trailer/assets/.env` and insert your service tokens:
```env
    CLOUDINARY_CLOUD_NAME=your_cloud_name
    CLOUDINARY_UPLOAD_PRESET=your_upload_preset
    ```
  </Step>
  <Step subtitle="Step 5" title="Select Target Device & Run">
    Click the target platform option on the bottom right status bar of VS Code to choose between **Web Localhost**, an **Android Studio Mobile Emulator**, or a connected **Real Android Mobile Device**. Press **F5** or run the targeted launch command to start the app:
```bash
    flutter run -t lib/main.dart
    ```
  </Step>
</Sequence>

---

## 📁 Module Directory Structure

```text
trailer/
├── assets/
│   └── .env               # Local secret variables (Cloudinary API maps)
├── lib/
│   ├── main.dart          # Application entry-point
│   └── firebase_options.dart # Local Firebase environment setup
├── android/               # Native Android target configurations
└── ios/                   # Native iOS target configurations
