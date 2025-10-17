# Smart Water Tank - Full-Stack IoT Project 💧

This is a complete, production-ready IoT solution for monitoring and controlling a water tank from a Flutter mobile app. The system uses an ESP32 for hardware control and Firebase for all backend services.

---

## 🎥 Project Demo

  will be available soon

![Screenshot of the app dashboard]
![Photo of the ESP32 hardware]

---

## 🌟 Key Features

* **Real-time Monitoring:** Live water level percentage streamed directly to the app.
* **Dual-Mode Control:**
    * **Auto Mode:** Automatically turns the pump ON at 10% and OFF at 95%.
    * **Manual Mode:** Toggle the pump from the app at any time.
* **Push Notifications:** Instant alerts for "Tank Full" and "Tank Empty" sent via FCM, even when the app is closed.
* **Full User Control:**
    * Enable or disable all notifications from the app's settings.
    * Set the specific height of your tank for accurate percentage calculations.
* **History:** A full, time-stamped log of all motor "ON" and "OFF" events.
* **Secure Authentication:** 3-level security (Hardware, User, and Database) to ensure data is safe.

---

## 🛠️ Tech Stack & Architecture

This project is built on a full-stack architecture, from hardware to the cloud and the mobile app.

### **Tech Stack**
* **Mobile App:** Flutter & Dart
* **Backend:** Firebase Realtime Database, Firebase Cloud Functions (Node.js)
* **Hardware:** ESP32, Ultrasonic Sensor (HC-SR04), 5V Relay
* **Authentication:** Firebase Auth (for users) & Cloud Firestore (for device API key registry)

### **System Architecture**
  available soon
![My Project Flowchart](system_flowchart.png)

### **Hardware Wiring Diagram**
 available soon
![My AutoCAD Wiring Diagram](wiring_diagram.png)

---

## ⚠️ How to Set Up (Configuration)

This project uses dummy data for all API keys. To run it, you must use your own Firebase project and keys.

### 1. Flutter App
You must add your own Firebase configuration to `/lib/firebase_options.dart`.

### 2. ESP32 Firmware
You must add your own keys and URLs to the main `.ino` file.
* `FIREBASE_API_KEY`
* `FIREBASE_DATABASE_URL`
* `tokenFunctionUrl`

### 3. Firebase Rules
You must add the secure database rules from the `database.rules.json` file to your Firebase project to secure user data.
