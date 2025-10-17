// lib/provisioning/ble_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// --- MODIFIED: UUIDs are updated for the new provisioning flow ---
const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String wifiSsidCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String wifiPassCharUuid = "c3c2e5d6-332c-42d4-a5e2-1bf2c65f7375";
// NEW: For reading the device's unique hardware ID (MAC address)
const String macAddressCharUuid = "a8a1e505-0792-411a-811c-25f053248c82";
// NEW: For writing the permanent API key
const String apiKeyCharUuid = "25b70446-f2b1-4a39-8ac1-83a3754e27f0";

class BleProvisioningResult {
  final BluetoothDevice device;
  final String macAddress;
  BleProvisioningResult(this.device, this.macAddress);
}

class BleService {
  // --- MODIFIED: This function now connects, sends Wi-Fi, and returns the device's MAC address ---
  Future<BleProvisioningResult?> connectAndProvisionWifi(
      String ssid, String password, Function(String) onStatusUpdate) async {
    BluetoothDevice? targetDevice;
    StreamSubscription<List<ScanResult>>? scanSubscription;
    int negotiatedMtu = 23; // Default BLE MTU

    try {
      onStatusUpdate("Scanning for your device...");
      final completer = Completer<BluetoothDevice>();

      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // IMPORTANT: Ensure your ESP32 is advertising this service UUID
          if (r.advertisementData.serviceUuids.contains(Guid(serviceUuid))) {
            debugPrint('Found target device: ${r.device.platformName}');
            if (!completer.isCompleted) {
              completer.complete(r.device);
            }
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      targetDevice = await completer.future.timeout(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      await scanSubscription.cancel();

      onStatusUpdate("Connecting to device...");
      await targetDevice.connect(autoConnect: false, timeout: const Duration(seconds: 15));

      onStatusUpdate("Negotiating packet size...");
      negotiatedMtu = await targetDevice.requestMtu(512);
      await Future.delayed(const Duration(milliseconds: 400));

      onStatusUpdate("Discovering services...");
      final provisioningService = await _getProvisioningService(targetDevice);
      if (provisioningService == null) {
        throw "Required BLE service not found on the device.";
      }

      onStatusUpdate("Sending Wi-Fi credentials...");
      await _writeCharacteristic(provisioningService, wifiSsidCharUuid, ssid, negotiatedMtu);
      await _writeCharacteristic(provisioningService, wifiPassCharUuid, password, negotiatedMtu);

      onStatusUpdate("Reading device hardware ID...");
      final macAddress = await _readCharacteristic(provisioningService, macAddressCharUuid);
      if (macAddress.isEmpty) {
        throw "Could not read device hardware ID (MAC address).";
      }
      debugPrint("Read hardware ID: $macAddress");

      // We return the connected device and its MAC, but we DO NOT disconnect yet.
      return BleProvisioningResult(targetDevice, macAddress);

    } on TimeoutException catch (_) {
      await FlutterBluePlus.stopScan();
      await scanSubscription?.cancel();
      onStatusUpdate("Device not found. Make sure it's powered on and nearby.");
      return null;
    } catch (e) {
      await FlutterBluePlus.stopScan();
      await scanSubscription?.cancel();
      await targetDevice?.disconnect();
      onStatusUpdate("An error occurred: ${e.toString()}");
      debugPrint(e.toString());
      return null;
    }
  }

  // --- NEW: This function sends the final API key and disconnects ---
  Future<bool> sendApiKeyAndDisconnect(BluetoothDevice device, String apiKey, Function(String) onStatusUpdate) async {
    try {
      onStatusUpdate("Sending permanent API key...");
      final provisioningService = await _getProvisioningService(device);
      if (provisioningService == null) {
        throw "Required BLE service not found on the device.";
      }

      final negotiatedMtu = await device.mtu.first;
      await _writeCharacteristic(provisioningService, apiKeyCharUuid, apiKey, negotiatedMtu);

      await device.disconnect();
      onStatusUpdate("Setup complete! Your device is now registered.");
      return true;
    } catch (e) {
      onStatusUpdate("Failed to send API key: ${e.toString()}");
      await device.disconnect();
      return false;
    }
  }

  Future<BluetoothService?> _getProvisioningService(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid == Guid(serviceUuid)) {
        return service;
      }
    }
    return null;
  }

  Future<String> _readCharacteristic(BluetoothService service, String charUuid) async {
    for (var char in service.characteristics) {
      if (char.uuid == Guid(charUuid)) {
        final value = await char.read();
        return utf8.decode(value);
      }
    }
    throw "Characteristic $charUuid not found!";
  }

  Future<void> _writeCharacteristic(BluetoothService service, String charUuid, String data, int mtu) async {
    BluetoothCharacteristic? targetChar;
    for (var char in service.characteristics) {
      if (char.uuid == Guid(charUuid)) {
        targetChar = char;
        break;
      }
    }

    if (targetChar != null) {
      List<int> bytes = utf8.encode(data);
      int chunkSize = mtu - 3;

      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);
        await targetChar.write(chunk, withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 40));
      }
    } else {
      throw "Characteristic $charUuid not found!";
    }
  }
}