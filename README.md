# 🚨 HelpSignal

**HelpSignal** is an offline-first disaster emergency communication app that enables users to send and receive alerts without relying on internet or cellular networks.

It uses **Bluetooth Low Energy (BLE)** to create a decentralized mesh network, allowing nearby devices to relay emergency signals across multiple hops.

---

## 🧠 Problem

During disasters (earthquakes, floods, network outages), traditional communication systems fail:

- No internet
- No cellular network
- Victims cannot reach help

HelpSignal solves this by enabling **device-to-device communication** without infrastructure.

---

## 🚀 Features

### 🔴 Emergency Alerts

- **SOS** – Critical distress signal
- **Medical** – Health-related emergencies
- **Rescue** – Assistance or search requests
- **Hazard** – Environmental danger alerts

---

### 📡 Offline Mesh Communication

- Uses **Bluetooth Low Energy (BLE)**
- Peer-to-peer discovery
- Multi-hop message relay (mesh network)
- Works completely **offline**

---

### 🗺️ Live Map View

- Displays nearby alerts and user location
- Distance-based awareness (e.g., _200m away_)
- Visual connection between users and alerts

---

### 📋 Alerts Feed

- Real-time alert list
- Shows:
  - Type
  - Distance
  - Time
- Quick actions:
  - Respond
  - Monitor
  - View details

---

### 🎯 User Experience

- Simple, stress-friendly UI
- One-tap SOS trigger
- Clear visual hierarchy
- Designed for use under emergency conditions

---

## 🧱 Tech Stack

- **Flutter** (UI Framework)
- **Dart**
- **Bluetooth Low Energy (BLE)** APIs
- **Local Storage** (Hive / SQLite)
- **OpenStreetMap** (offline maps)

---