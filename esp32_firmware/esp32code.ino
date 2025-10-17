
#include <WiFi.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <time.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "mbedtls/base64.h"

//~// --- PROJECT SETTINGS ---
#define FIREBASE_API_KEY "api key" // ✅ Replace with your Firebase Web API Key
#define FIREBASE_DATABASE_URL "your database url" // ✅ Replace with your Database URL
const char* tokenFunctionUrl = "your token function url"; // ✅ Replace with your Cloud Function URL

// ✅ Using a memory-efficient "raw string literal" to define the certificate
const char* root_ca = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw
CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU
MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw
MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp
Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA
A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo
27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w
Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw
TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl
qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH
szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8
Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk
MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92
wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p
aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN
VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID
AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb
C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe
QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy
h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4
7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J
ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef
MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/
Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT
6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ
0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm
2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb
bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c
-----END CERTIFICATE-----
)EOF";

#define TRIG_PIN 26
#define ECHO_PIN 25
#define RELAY_PIN 27
#define LED_PIN 2
#define RESET_BUTTON_PIN 15
#define DEFAULT_TANK_HEIGHT_CM 30.0

FirebaseData fbdo;
FirebaseData stream;
FirebaseAuth auth;
FirebaseConfig config;
Preferences preferences;
Adafruit_SSD1306 display(128, 64, &Wire, -1);
DynamicJsonDocument doc(1024);

String receivedSsid = "", receivedPass = "", deviceUID = "";
volatile bool restartNeeded = false;
unsigned long lastUpdateTime = 0, token_issue_time = 0;
const int updateInterval = 5000;
bool currentAutoMode = true;
int currentLevelPercent = 0;
float tank_height_cm = DEFAULT_TANK_HEIGHT_CM;

// Function Forward Declarations
void displayMessage(const String &msg, int size = 2);
void updateDisplay();
void startBleSetup();
String getFirebaseIdToken();
void streamCallback(FirebaseStream data);
void streamTimeoutCallback(bool timeout);
String getUidFromToken(String token);
void addMotorHistoryEvent(String eventText);


String getUidFromToken(String token) {
  int firstDot = token.indexOf('.');
  int secondDot = token.indexOf('.', firstDot + 1);
  if (firstDot == -1 || secondDot == -1) return "";
  String payload = token.substring(firstDot + 1, secondDot);
  payload.replace('-', '+');
  payload.replace('_', '/');
  while (payload.length() % 4) payload += "=";
  unsigned char decoded[1024];
  size_t decoded_len;
  mbedtls_base64_decode(decoded, sizeof(decoded), &decoded_len, (const unsigned char*)payload.c_str(), payload.length());
  String jsonPayload = "";
  for(size_t i = 0; i < decoded_len; i++) jsonPayload += (char)decoded[i];
  DynamicJsonDocument tempDoc(1024);
  deserializeJson(tempDoc, jsonPayload);
  if (tempDoc.containsKey("uid")) return tempDoc["uid"].as<String>();
  if (tempDoc.containsKey("user_id")) return tempDoc["user_id"].as<String>();
  return "";
}

void addMotorHistoryEvent(String eventText) {
  if (!Firebase.ready() || deviceUID.isEmpty()) {
    Serial.println("Cannot send history, Firebase not ready or UID is missing.");
    return;
  }
  Serial.println("Attempting to send motor history: " + eventText); 
  FirebaseJson json;
  json.set("event", eventText);
  json.set("timestamp/.sv", "timestamp");
  String historyPath = "/tanks/" + deviceUID + "/motor_history";
  if (Firebase.RTDB.pushJSON(&fbdo, historyPath.c_str(), &json)) {
    Serial.println("SUCCESS: Motor history event sent!");
  } else {
    Serial.println("!!!!!!!!!! FAILED to send motor history !!!!!!!!!!");
    Serial.println("REASON: " + fbdo.errorReason());
  }
}

void streamCallback(FirebaseStream data) {
  bool pumpStateChanged = false;
  bool newPumpState = false;
  bool currentPumpStateIsOn = (digitalRead(RELAY_PIN) == LOW);

  if (data.eventType() == "put" && data.dataPath() == "/") {
    doc.clear();
    if (deserializeJson(doc, data.payload()) != DeserializationError::Ok) return;
    if (doc.containsKey("auto_mode")) currentAutoMode = doc["auto_mode"].as<bool>();
    if (doc.containsKey("pump_status")) {
      bool pump_status_from_app = doc["pump_status"].as<bool>();
      if (!currentAutoMode && pump_status_from_app != currentPumpStateIsOn) {
        digitalWrite(RELAY_PIN, pump_status_from_app ? LOW : HIGH);
        pumpStateChanged = true;
        newPumpState = pump_status_from_app;
      }
    }
    if (doc.containsKey("tank_height_cm")) tank_height_cm = doc["tank_height_cm"].as<float>();
  } else if (data.eventType() == "put") {
    String key = data.dataPath();
    if (key.startsWith("/")) key.remove(0, 1);
    
    if (key == "pump_status" && data.dataTypeEnum() == fb_esp_rtdb_data_type_boolean) {
      bool pump_status_from_app = data.to<bool>();
      if (!currentAutoMode && pump_status_from_app != currentPumpStateIsOn) {
        digitalWrite(RELAY_PIN, pump_status_from_app ? LOW : HIGH);
        pumpStateChanged = true;
        newPumpState = pump_status_from_app;
      }
    } else if (key == "auto_mode" && data.dataTypeEnum() == fb_esp_rtdb_data_type_boolean) {
      currentAutoMode = data.to<bool>();
    } else if (key == "tank_height_cm" && (data.dataTypeEnum() == fb_esp_rtdb_data_type_integer || data.dataTypeEnum() == fb_esp_rtdb_data_type_float)) {
      tank_height_cm = data.to<float>();
    }
  }

  if (pumpStateChanged) {
    String event = newPumpState ? "Motor Turned ON" : "Motor Turned OFF";
    addMotorHistoryEvent(event);
  }
  
  updateDisplay();
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) Serial.println("Stream timeout, resuming...");
}

// ... BLE Callbacks and Setup remain the same ...
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) override {
        String valueStr = pCharacteristic->getValue().c_str();  
        String uuid_str = String(pCharacteristic->getUUID().toString().c_str());
        if (uuid_str.equals("beb5483e-36e1-4688-b7f5-ea07361b26a8")) receivedSsid = valueStr;
        else if (uuid_str.equals("c3c2e5d6-332c-42d4-a5e2-1bf2c65f7375")) receivedPass = valueStr;
        else if (uuid_str.equals("25b70446-f2b1-4a39-8ac1-83a3754e27f0")) {
            preferences.begin("my-app", false);
            preferences.putString("wifi_ssid", receivedSsid);
            preferences.putString("wifi_pass", receivedPass);
            preferences.putString("api_key", valueStr);
            preferences.end();
            displayMessage("SAVED!");
            restartNeeded = true;
        }
    }
};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override { Serial.println("[DEBUG] BLE Client connected"); }
    void onDisconnect(BLEServer* pServer) override {
      pServer->getAdvertising()->start();
      Serial.println("[DEBUG] BLE Client disconnected");
    }
};

void startBleSetup() {
  displayMessage("Setup Mode");
  BLEDevice::init("Water Tank Setup");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  pService->createCharacteristic("beb5483e-36e1-4688-b7f5-ea07361b26a8", BLECharacteristic::PROPERTY_WRITE)->setCallbacks(new MyCallbacks());
  pService->createCharacteristic("c3c2e5d6-332c-42d4-a5e2-1bf2c65f7375", BLECharacteristic::PROPERTY_WRITE)->setCallbacks(new MyCallbacks());
  pService->createCharacteristic("25b70446-f2b1-4a39-8ac1-83a3754e27f0", BLECharacteristic::PROPERTY_WRITE)->setCallbacks(new MyCallbacks());
  pService->createCharacteristic("a8a1e505-0792-411a-811c-25f053248c82", BLECharacteristic::PROPERTY_READ)->setValue(WiFi.macAddress().c_str());
  pService->start();
  BLEDevice::getAdvertising()->addServiceUUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  BLEDevice::getAdvertising()->start();
}

String getFirebaseIdToken() {
  String permanentApiKey;
  preferences.begin("my-app", true);
  permanentApiKey = preferences.getString("api_key", "");
  preferences.end();
  if (permanentApiKey.isEmpty()) return "";
  displayMessage("AUTH(1/2)");
  String customToken = "";
  WiFiClientSecure client;
  HTTPClient http;
  client.setCACert(root_ca);
  if (http.begin(client, tokenFunctionUrl)) {
    http.addHeader("Authorization", "Bearer " + permanentApiKey);
    if (http.GET() == HTTP_CODE_OK) {
      DynamicJsonDocument tempDoc(2048);
      if (deserializeJson(tempDoc, http.getString()) == DeserializationError::Ok) {
        customToken = tempDoc["token"].as<String>();
      }
    }
    http.end();
  }
  if (customToken.isEmpty()) return "";
  displayMessage("AUTH(2/2)");
  HTTPClient http2;
  String idToken = "";
  String identityToolkitUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=" + String(FIREBASE_API_KEY);
  if (http2.begin(client, identityToolkitUrl)) { 
    http2.addHeader("Content-Type", "application/json");
    DynamicJsonDocument postDoc(256);
    postDoc["token"] = customToken;
    postDoc["returnSecureToken"] = true;
    String postPayload;
    serializeJson(postDoc, postPayload);
    if (http2.POST(postPayload) == HTTP_CODE_OK) {
      DynamicJsonDocument responseDoc(1024);
      if (deserializeJson(responseDoc, http2.getString()) == DeserializationError::Ok) {
        idToken = responseDoc["idToken"].as<String>();
      }
    }
    http2.end();
  }
  return idToken;
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
  digitalWrite(RELAY_PIN, HIGH);
  Wire.begin();
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {  
    Serial.println(F("SSD1306 allocation failed"));
  }
  displayMessage("Starting...");
  
  preferences.begin("my-app", true);
  bool isProvisioned = preferences.isKey("api_key");
  preferences.end();
  
  if (!isProvisioned) {  
    startBleSetup();  
    return; 
  }
  
  BLEDevice::deinit(true);
  
  displayMessage("Connecting WiFi...");
  preferences.begin("my-app", true);
  String ssid = preferences.getString("wifi_ssid", "");
  String pass = preferences.getString("wifi_pass", "");
  preferences.end();
  WiFi.begin(ssid.c_str(), pass.c_str());
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500); Serial.print("."); attempts++;
  }
  if (WiFi.status() != WL_CONNECTED) {
    displayMessage("WiFi FAIL"); delay(2000); startBleSetup(); return;
  }
  
  displayMessage("WiFi OK!");
  configTime(19800, 0, "pool.ntp.org");
  time_t now = time(nullptr);
  while (now < 1728000000) {
    delay(500); now = time(nullptr);
  }
  
  String idToken = getFirebaseIdToken();
  if (idToken.isEmpty()) { 
    displayMessage("AUTH FAIL");  
    return; 
  }
  
  config.api_key = FIREBASE_API_KEY;
  config.database_url = FIREBASE_DATABASE_URL;
  config.signer.tokens.legacy_token = idToken.c_str();
  token_issue_time = millis();  
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  if (Firebase.ready()) {
    deviceUID = getUidFromToken(idToken);
    if (deviceUID.length() > 0) {
      String streamPath = "/tanks/" + deviceUID + "/controls";
      if (!Firebase.RTDB.beginStream(&stream, streamPath)) {
        Serial.printf("❌ Stream begin failed: %s\n", stream.errorReason().c_str());
      } else {
        Firebase.RTDB.setStreamCallback(&stream, streamCallback, streamTimeoutCallback);
      }
    } else {
      displayMessage("UID FAIL");
    }
  } else {
    displayMessage("AUTH FAIL");
  }
}

void loop() {
  if (restartNeeded) { delay(1000); ESP.restart(); }
  if (digitalRead(RESET_BUTTON_PIN) == LOW) {
    long pressStartTime = millis();
    while (digitalRead(RESET_BUTTON_PIN) == LOW) {}
    if (millis() - pressStartTime > 5000) {
      displayMessage("RESETTING");
      preferences.begin("my-app", false);
      preferences.clear();
      preferences.end();
      delay(1000);
      ESP.restart();
    }
  }
  
  if (WiFi.status() == WL_CONNECTED && Firebase.ready() && deviceUID.length() > 0) {
    if (millis() - token_issue_time > 3300000) {
        String newIdToken = getFirebaseIdToken(); 
        if (newIdToken.length() > 0) {
            config.signer.tokens.legacy_token = newIdToken.c_str();
            Firebase.begin(&config, &auth); 
            token_issue_time = millis();
            deviceUID = getUidFromToken(newIdToken);
            if (deviceUID.length() > 0) {
                String streamPath = "/tanks/" + deviceUID + "/controls";
                if (Firebase.RTDB.beginStream(&stream, streamPath)) {
                  Firebase.RTDB.setStreamCallback(&stream, streamCallback, streamTimeoutCallback);
                }
            }
        }
    }

    if (millis() - lastUpdateTime > updateInterval) {
      lastUpdateTime = millis();
      digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
      digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
      digitalWrite(TRIG_PIN, LOW);
      
      long duration = pulseIn(ECHO_PIN, HIGH, 30000);
      
      if (duration > 0 && !deviceUID.isEmpty()) {
        float distanceCm = duration * 0.034 / 2;

        // =================================================================
        // ===            ✅ START: 20cm DEAD ZONE FIX ✅                ===
        // =================================================================
        // Check if the reading is inside the 20cm dead zone (but not an error 0)
        if (distanceCm < 20.0 && distanceCm > 0.0) {
          // Sensor is in the dead zone, so we assume the tank is full.
          currentLevelPercent = 100;
        } else {
          // Reading is valid, calculate the level normally.
          currentLevelPercent = 100 - (int)(distanceCm / tank_height_cm * 100.0);
        }
        // =================================================================
        // ===             ✅ END: 20cm DEAD ZONE FIX ✅                 ===
        // =================================================================

        currentLevelPercent = constrain(currentLevelPercent, 0, 100);
        
        String liveDataPath = "/tanks/" + deviceUID + "/live_data";
        
        FirebaseJson json;
        json.set("water_level", currentLevelPercent);
        json.set("last_updated/.sv", "timestamp");
        Firebase.RTDB.setJSON(&fbdo, liveDataPath.c_str(), &json);
        
        if (currentAutoMode) {
          bool currentPumpStateIsOn = (digitalRead(RELAY_PIN) == LOW);
          bool newPumpStateShouldBeOn = currentPumpStateIsOn;

          if (currentLevelPercent <= 10) newPumpStateShouldBeOn = true;
          else if (currentLevelPercent >= 95) newPumpStateShouldBeOn = false;

          if (newPumpStateShouldBeOn != currentPumpStateIsOn) {
            digitalWrite(RELAY_PIN, newPumpStateShouldBeOn ? LOW : HIGH);
            String pumpStatusPath = "/tanks/" + deviceUID + "/controls/pump_status";
            Firebase.RTDB.setBool(&fbdo, pumpStatusPath.c_str(), newPumpStateShouldBeOn);
            String event = newPumpStateShouldBeOn ? "Motor Turned ON" : "Motor Turned OFF";
            addMotorHistoryEvent(event);
          }
        }
      }
      digitalWrite(LED_PIN, !digitalRead(RELAY_PIN));
      updateDisplay();
    }
  } else {
    digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    delay(500);
  }
}

void displayMessage(const String &msg, int size) {
  display.clearDisplay();
  display.setTextSize(size);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 10);
  display.println(msg);
  display.display();
}

void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.print("Level:");
  display.setCursor(0, 20);
  display.print(currentLevelPercent);
  display.print("%");
  display.setTextSize(1);
  display.setCursor(0, 45);
  display.print("Pump: ");
  display.print(digitalRead(RELAY_PIN) == LOW ? "ON" : "OFF");
  display.setCursor(0, 55);
  display.print("Mode: ");
  display.print(currentAutoMode ? "AUTO" : "MANUAL");
  display.display();
}
