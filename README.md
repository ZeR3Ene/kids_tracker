# 📍 Kids Tracker – Smart Child Tracking System  

## 📌 Project Description  
Kids Tracker is a mobile application developed using Flutter to track children's smartwatches in real time. The system integrates ESP32, GPS, and Firebase to provide accurate location tracking and enhance child safety.  

The application allows parents to monitor their child's location, receive alerts, and manage tracking features through a simple and user-friendly interface.  

---

## 🎯 Project Goals  
- Real-time location tracking for children's smartwatches  
- Provide safety alerts when the child leaves a defined area  
- Enable parents to monitor their child easily through a mobile app  
- Ensure a smooth and responsive user experience  

---

## ✨ Features  
- User authentication (Google & Facebook)  
- Real-time GPS tracking  
- Display location on Google Maps  
- Safe zone alerts and notifications  
- Activity monitoring and statistics  
- Custom settings for each child  
- Clean and responsive UI  

---

## 🛠️ Technologies Used  

### 🔹 Hardware  
- ESP32  
- GPS Module  

### 🔹 Software  
- Flutter (mobile application)  
- Firebase (Authentication, Realtime Database)  
- Google Maps API  
- REST APIs  

---

## 🔍 How the System Works  

### 1. Data Collection  
- The smartwatch (ESP32 + GPS) collects location data  

### 2. Data Transmission  
- Data is sent to Firebase in real time  

### 3. Application Layer  
- The mobile app retrieves and displays the location on Google Maps  

### 4. Notifications  
- Alerts are triggered when the child leaves a safe zone  

---

## 📂 Project Structure  

lib/  
├── main.dart  
├── models/  
├── screens/  
├── widgets/  
└── utils/  

---

## 🎓 About the Project  
This project was developed as my graduation project in Computer Systems Engineering. It helped me strengthen my skills in mobile development using Flutter, IoT integration, and real-time data processing.  

---

## 📌 Future Improvements  
- Improve location accuracy  
- Add emergency (SOS) feature  
- Enhance UI/UX  
- Support more wearable devices  
