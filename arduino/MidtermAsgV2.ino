#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// OLED display settings
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Device ID (Change this if you have multiple devices)
const int DEVICE_ID = 1;

// WiFi credentials (Set your credentials here)
const char* ssid = "<YOUR_SSID>";
const char* password = "<YOUR_PASSWORD>";

// Backend API endpoint
const char* serverUrl = "<YOUR_SERVER_URL>";

// Pin definitions
#define DHTPIN 4
#define DHTTYPE DHT11
#define RELAY_PIN 5

// Thresholds
float tempThreshold = 26.0;
float humThreshold = 70.0;

DHT dht(DHTPIN, DHTTYPE);

unsigned long lastReadTime = 0;
const unsigned long readInterval = 10000;

void initDisplay() {
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("SSD1306 allocation failed");
    for (;;);
  }

  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Starting...");
  display.display();
  delay(1000);
}

void updateDisplay(float temperature, float humidity, bool relayState, bool wifiConnected, String ipAddress) {
  display.clearDisplay();
  display.setTextSize(2);

  display.setCursor(0, 0);
  display.print("T: ");
  display.print(temperature, 1);
  display.println(" C");

  display.setCursor(0, 24);
  display.print("H:  ");
  display.print(humidity, 1);
  display.println(" %");

  display.setCursor(0, 48);
  display.print("Relay: ");
  display.println(relayState ? "ON" : "OFF");

  display.display();
}

void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.println("Connecting to WiFi");
  display.display();

  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000);
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int attempts = 0;
  const int maxAttempts = 30;

  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");
    display.print(".");
    display.display();
    attempts++;

    Serial.print("WiFi status: ");
    Serial.println(WiFi.status());
  }

  if (WiFi.status() == WL_CONNECTED) {
    String ipAddress = WiFi.localIP().toString();
    Serial.println("\nConnected to WiFi successfully!");
    Serial.print("IP Address: ");
    Serial.println(ipAddress);
    Serial.print("Signal Strength (RSSI): ");
    Serial.println(WiFi.RSSI());

    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi Connected!");
    display.print("IP: ");
    display.println(ipAddress);
    display.print("RSSI: ");
    display.println(WiFi.RSSI());
    display.display();
    delay(2000);
  } else {
    Serial.println("\nFailed to connect to WiFi!");
    Serial.println("Last WiFi status: " + String(WiFi.status()));

    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi Connection");
    display.println("Failed!");
    display.println("Status: " + String(WiFi.status()));
    display.println("RSSI: " + String(WiFi.RSSI()));
    display.display();
    delay(2000);
  }
}

bool readSensorData(float &temperature, float &humidity) {
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Failed to read from DHT sensor!");

    display.clearDisplay();
    display.setCursor(0, 0);
    display.setTextSize(1);
    display.println("Sensor Error!");
    display.println("Check connections:");
    display.println("VCC -> 3.3V");
    display.println("GND -> GND");
    display.println("DATA -> GPIO4");
    display.display();
    delay(2000);
    return false;
  }
  return true;
}

void controlRelay(float temperature, float humidity) {
  if (temperature > tempThreshold || humidity > humThreshold) {
    digitalWrite(RELAY_PIN, HIGH);
    Serial.println("Relay turned ON - Threshold exceeded");
  } else {
    digitalWrite(RELAY_PIN, LOW);
    Serial.println("Relay turned OFF - Within threshold");
  }
}

bool sendDataToServer(float temperature, float humidity, bool relayState) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected!");
    return false;
  }

  HTTPClient http;
  http.begin(serverUrl);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<200> doc;
  doc["device_id"] = DEVICE_ID;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["relay_state"] = relayState ? 1 : 0;
  doc["timestamp"] = millis() / 1000;

  String jsonString;
  serializeJson(doc, jsonString);

  Serial.print("Sending data to server: ");
  Serial.println(jsonString);

  int httpResponseCode = http.POST(jsonString);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("HTTP Response code: " + String(httpResponseCode));
    Serial.println("Response: " + response);
    http.end();
    return true;
  } else {
    Serial.print("Error sending HTTP request. Error code: ");
    Serial.println(httpResponseCode);
    http.end();
    return false;
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\nStarting setup...");

  initDisplay();
  dht.begin();
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  connectToWiFi();

  Serial.println("\nWiFi Status Codes:");
  Serial.println("WL_IDLE_STATUS = 0");
  Serial.println("WL_NO_SSID_AVAIL = 1");
  Serial.println("WL_CONNECT_FAILED = 2");
  Serial.println("WL_CONNECTION_LOST = 3");
  Serial.println("WL_DISCONNECTED = 4");
  Serial.println("WL_CONNECTED = 3");
}

void loop() {
  unsigned long currentTime = millis();

  if (currentTime - lastReadTime >= readInterval) {
    lastReadTime = currentTime;

    float temperature, humidity;
    if (readSensorData(temperature, humidity)) {
      controlRelay(temperature, humidity);
      bool relayState = digitalRead(RELAY_PIN);
      sendDataToServer(temperature, humidity, relayState);
      updateDisplay(temperature, humidity, relayState, WiFi.status() == WL_CONNECTED, WiFi.localIP().toString());

      Serial.println("\nSensor Readings:");
      Serial.print("Temperature: ");
      Serial.print(temperature);
      Serial.print("°C, Humidity: ");
      Serial.print(humidity);
      Serial.println("%\n");
    }
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi connection lost! Attempting to reconnect...");
    connectToWiFi();
  }
}
