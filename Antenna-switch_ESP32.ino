/*
 * ESP32-C3 Super Mini – 5 GPIO Web-Controlled Outputs
 * Static IP | Single-active-output enforced
 * Arduino IDE – works with ESP32 Arduino core v2 AND v3
 */

#include <WiFi.h>

// ─── USER CONFIG ──────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "WIFI-SSID";
const char* WIFI_PASSWORD = "WIFI-PASS";

IPAddress staticIP (192, 168,   1,  15);
IPAddress gateway  (192, 168,   1,   1);
IPAddress subnet   (255, 255, 255,   0);
IPAddress dns1     (  8,   8,   8,   8);

// GPIO pins (avoid strapping pins 2, 8, 9)
const uint8_t GPIO_PINS[5] = {3, 4, 5, 6, 7};
const char*   PIN_NAMES[5] = {"Antenna 1", "Antenna 2", "Antenna 3", "Antenna 4", "Antenna 5"};
// ──────────────────────────────────────────────────────────────────────────────

WiFiServer server(80);
int activePin = -1;   // index of currently HIGH pin, -1 = all OFF

// ─── GPIO helpers ─────────────────────────────────────────────────────────────
void setPin(int idx) {
  for (int i = 0; i < 5; i++)
    digitalWrite(GPIO_PINS[i], (i == idx) ? HIGH : LOW);
  activePin = idx;
}

void allOff() {
  for (int i = 0; i < 5; i++) digitalWrite(GPIO_PINS[i], LOW);
  activePin = -1;
}

// ─── HTML page ────────────────────────────────────────────────────────────────
String buildPage() {
  String h = F("<!DOCTYPE html><html lang='en'><head>"
    "<meta charset='UTF-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>Antenna switch 1</title><style>"
    "*{box-sizing:border-box;margin:0;padding:0}"
    "body{font-family:Arial,sans-serif;background:#1a1a2e;color:#eee;"
         "display:flex;flex-direction:column;align-items:center;padding:30px 16px}"
    "h1{margin-bottom:6px;font-size:1.4rem;color:#e94560}"
    "p{margin-bottom:24px;font-size:.82rem;color:#aaa}"
    "p.sub{margin-bottom:24px;font-size:.82rem;color:#aaa}"
    ".grid{display:grid;gap:12px;width:100%;max-width:360px}"
    "a.btn{display:flex;justify-content:space-between;align-items:center;"
          "padding:15px 18px;border-radius:10px;text-decoration:none;"
          "font-size:1rem;transition:filter .2s}"
    "a.off{background:#2a2a4a;color:#ccc}"
    "a.on {background:#e94560;color:#fff;box-shadow:0 0 14px #e9456077}"
    "a:hover{filter:brightness(1.25)}"
    ".badge{font-size:.7rem;padding:3px 8px;border-radius:20px;"
           "background:rgba(255,255,255,.15)}"
    "a.alloff{margin-top:18px;padding:11px 30px;border:2px solid #555;"
             "border-radius:10px;color:#aaa;text-decoration:none;font-size:.9rem}"
    "a.alloff:hover{border-color:#e94560;color:#e94560}"
    ".status{margin-top:16px;font-size:.78rem;color:#777}"
    "</style></head><body>"
    "<h1>&#9889; Antenna Switch Control</h1>"
    "<p class='sub'>Switch between antenna's </p>"
    "<div class='grid'>");

  for (int i = 0; i < 5; i++) {
    bool on = (activePin == i);
    h += "<a class='btn " + String(on ? "on" : "off") + "' href='/set?pin=" + i + "'>";
    h += "<span>" + String(PIN_NAMES[i]) + "</small></span>";
    h += "<span class='badge'>" + String(on ? "ON" : "OFF") + "</span></a>";
  }

  h += "</div><a class='alloff' href='/off'>&#9632; All OFF</a>";
  h += "<p class='status'>Active: ";
  h += (activePin >= 0)
       ? String(PIN_NAMES[activePin])
       : "None";
  h += "</p><p>by: PA3RPW 2026</p></body></html>";
  return h;
}

// ─── Send HTTP response ───────────────────────────────────────────────────────
void sendPage(WiFiClient& client) {
  String body = buildPage();
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html");
  client.println("Connection: close");
  client.print("Content-Length: ");
  client.println(body.length());
  client.println();
  client.print(body);
}

void sendRedirect(WiFiClient& client) {
  client.println("HTTP/1.1 303 See Other");
  client.println("Location: /");
  client.println("Connection: close");
  client.println();
}

// ─── Parse first request line, e.g. "GET /set?pin=2 HTTP/1.1" ────────────────
void handleRequest(WiFiClient& client, const String& reqLine) {
  if (reqLine.startsWith("GET /set")) {
    int p = reqLine.indexOf("pin=");
    if (p != -1) {
      int idx = reqLine.charAt(p + 4) - '0';
      if (idx >= 0 && idx < 5) setPin(idx);
    }
    sendRedirect(client);
  } else if (reqLine.startsWith("GET /off")) {
    allOff();
    sendRedirect(client);
  } else {
    sendPage(client);
  }
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);

  for (int i = 0; i < 5; i++) {
    pinMode(GPIO_PINS[i], OUTPUT);
    digitalWrite(GPIO_PINS[i], LOW);
  }

  if (!WiFi.config(staticIP, gateway, subnet, dns1))
    Serial.println("Static IP config failed");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting");

  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500); Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected! Open: http://" + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi FAILED – check SSID/password");
  }

  server.begin();
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  WiFiClient client = server.available();
  if (!client) return;

  String reqLine = "";
  unsigned long t = millis();

  // Read until we get the first line or timeout
  while (client.connected() && (millis() - t < 2000)) {
    if (client.available()) {
      char c = client.read();
      if (c == '\n') break;
      if (c != '\r') reqLine += c;
    }
  }

  // Drain remaining headers
  while (client.connected() && client.available())
    client.read();

  if (reqLine.length()) handleRequest(client, reqLine);

  client.stop();
}
