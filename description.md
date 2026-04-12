# 🚨 HelpSignal — Offline Disaster Communication System

HelpSignal is a decentralized, offline-first emergency communication system that enables smartphones to exchange alerts using Bluetooth Low Energy (BLE) without relying on internet or cellular infrastructure.

The system forms an **opportunistic mesh network**, where devices act as nodes that discover, receive, store, and relay messages across multiple hops.

---

# 🧠 Core Objective

Enable communication in environments where:

* Internet is unavailable
* Cellular networks are down
* Infrastructure is damaged

> The system must function entirely using local device-to-device communication.

---

# 🏗️ Architecture Overview

```
UI → Controller → Managers → Services → Hardware (BLE, GPS)
```

---

# 📱 UI Layer

* **Home Screen** → Send SOS / alerts
* **Map Screen** → Visualize alerts and navigation
* **Alerts Screen** → View and act on alerts

---

# 🎛️ Controller Layer

## AlertController

Acts as a bridge between UI and logic.

Responsibilities:

* Handle user actions
* Create alerts
* Forward data to managers
* Handle incoming alerts

---

# ⚙️ Core Managers

## 🔹 AlertManager

* createAlert()
* storeAlert()
* isDuplicate()

Handles:

* Alert lifecycle
* Deduplication
* Local storage

---

## 🔹 MeshManager

* broadcastAlert()
* receiveAlert()
* relayAlert()

Handles:

* Mesh propagation
* TTL (hop count)
* Message relaying

---

## 🔹 LocationManager

* getCurrentLocation()
* calculateDistance()

Handles:

* GPS
* Distance calculations

---

# 🔌 Services Layer

## 🔹 BLEService

* startAdvertising()
* startScanning()
* sendData()
* receiveData()

Handles:

* Device discovery
* Data exchange

---

## 🔹 StorageService

Handles:

* Alert storage
* Seen message IDs

---

# 📡 Alert Message Format (FINAL)

## Dart Model

```dart
class AlertMessage {
  final String messageId;
  final AlertType type;

  final double latitude;
  final double longitude;

  final int timestamp;
  final int hopCount;

  final int? descriptionCode;
  final String senderId;
}
```

---

## Serialized Format (BLE Packet)

```json
{
  "id": "a1b2c3",
  "t": "sos",
  "lat": 28.61,
  "lng": 77.23,
  "ts": 1712345678,
  "hop": 1,
  "desc": 1,
  "sid": "device_123"
}
```

---

# 🧠 Field Explanation

* **messageId** → Unique identifier (UUID)
* **type** → Alert category (sos, medical, rescue, hazard)
* **latitude/longitude** → Location
* **timestamp** → Creation time
* **hopCount** → Controls propagation (TTL)
* **descriptionCode** → Predefined description index
* **senderId** → Unique device identifier

---

# 📝 Predefined Descriptions

```dart
const Map<AlertType, List<String>> predefinedDescriptions = {
  AlertType.sos: [
    "Severe accident",
    "Immediate danger",
    "Life-threatening situation",
  ],
  AlertType.medical: [
    "Heart attack",
    "Unconscious person",
    "Severe injury",
  ],
  AlertType.rescue: [
    "Trapped person",
    "Missing individual",
    "Need evacuation",
  ],
  AlertType.hazard: [
    "Fire",
    "Gas leak",
    "Flooded area",
  ],
};
```

---

# 🔄 Data Flow

## Sending Alert

```
User → Controller → AlertManager → MeshManager → BLE Broadcast
```

## Receiving Alert

```
BLE → MeshManager → AlertManager → Store → UI → Relay
```

---

# 🔁 Mesh Logic

## Deduplication

```
if messageId exists → DROP
```

## TTL Control

```
if hopCount > MAX → DROP
```

## Store-and-Forward

* Store alert if no devices nearby
* Send when device discovered

---

# 📍 Map System

* Uses OpenStreetMap via flutter_map
* Displays alerts and routes
* Offline support planned

---

# ⚡ Alert Types

| Type    | Action       |
| ------- | ------------ |
| SOS     | Navigate     |
| Medical | View Details |
| Rescue  | Navigate     |
| Hazard  | Safety Info  |

---

# 🎯 Design Principles

* Offline-first
* Decentralized
* Lightweight
* Simple UX

---

# ⚠️ Limitations

* Limited BLE range
* Requires nearby devices
* Basic routing

---

# 🔮 Future Scope

* Offline maps
* Improved routing
* Adaptive TTL
* Group coordination

---

# 🧠 Key Insight

HelpSignal is not just an app.

It is a **decentralized communication protocol implemented on smartphones**.

---

# 📌 Summary

HelpSignal enables communication where traditional systems fail by:

* Removing dependency on internet
* Using BLE mesh networking
* Supporting multi-hop communication

> Even when infrastructure fails, communication continues.
