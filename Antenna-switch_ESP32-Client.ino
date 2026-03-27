/*
 * ESP32-C3 Super Mini – Antenna Switch CLIENT
 * 5 push buttons + OLED 128x64 (I2C) + Web WiFi config portal
 *
 * First boot / no config: starts AP "AntClient-Setup" (open, no password)
 * Connect → browse to http://10.0.0.1 → pick WiFi from scan, set server IP
 *
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ─── FIXED CONFIG ─────────────────────────────────────────────────────────────
const uint8_t BTN_PINS[5]  = {3, 4, 5, 6, 7};
const uint8_t BTN_OFF      = 10;   // 6th button — all antennas OFF
// Antenna names (loaded from NVS, editable via config page)
String ANT_NAMES[5];

#define OLED_WIDTH  128
#define OLED_HEIGHT  64
#define OLED_ADDR  0x3C
#define OLED_RESET   -1

const unsigned long POLL_INTERVAL = 5000;

const char* AP_SSID = "AntClient-Setup";   // open AP, no password
const IPAddress AP_IP (10, 0, 0, 1);
const IPAddress AP_GW (10, 0, 0, 1);
const IPAddress AP_SN (255, 255, 255, 0);
// ──────────────────────────────────────────────────────────────────────────────

Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, OLED_RESET);
WiFiServer        cfgServer(80);
Preferences       prefs;

// Runtime config
String cfgSSID, cfgPass, cfgServerIP, cfgClientIP, cfgGateway, cfgSubnet;

bool   apMode        = false;
bool   serverOnline  = false;
bool   wifiConn      = false;
int    activeAntenna = -1;

unsigned long lastPoll = 0, lastBtn = 0;
bool btnPrev[5] = {};

// ─── NVS ──────────────────────────────────────────────────────────────────────
void loadConfig() {
  prefs.begin("antclient", true);
  cfgSSID     = prefs.getString("ssid",     "");
  cfgPass     = prefs.getString("pass",     "");
  cfgServerIP = prefs.getString("serverip", "192.168.178.15");
  cfgClientIP = prefs.getString("clientip", "");
  cfgGateway  = prefs.getString("gateway",  "");
  cfgSubnet   = prefs.getString("subnet",   "");
  ANT_NAMES[0] = prefs.getString("ant0", "Output 1");
  ANT_NAMES[1] = prefs.getString("ant1", "Output 2");
  ANT_NAMES[2] = prefs.getString("ant2", "Output 3");
  ANT_NAMES[3] = prefs.getString("ant3", "Output 4");
  ANT_NAMES[4] = prefs.getString("ant4", "Output 5");
  prefs.end();
}

void saveConfig(const String& ssid, const String& pass,
                const String& serverip, const String& clientip,
                const String& gw, const String& sn,
                String antNames[5]) {
  prefs.begin("antclient", false);
  prefs.putString("ssid",     ssid);
  prefs.putString("pass",     pass);
  prefs.putString("serverip", serverip);
  prefs.putString("clientip", clientip);
  prefs.putString("gateway",  gw);
  prefs.putString("subnet",   sn);
  for (int i = 0; i < 5; i++)
    prefs.putString(("ant" + String(i)).c_str(), antNames[i]);
  prefs.end();
}

// ─── OLED ─────────────────────────────────────────────────────────────────────
void drawScreen() {
  display.clearDisplay();
  display.fillRect(0, 0, OLED_WIDTH, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("ANT SWITCH PA3RPW");
  display.setTextColor(SSD1306_WHITE);

  if (apMode) {
    display.setCursor(2, 15); display.print("AP: AntClient-Setup");
    display.setCursor(2, 26); display.print("Open network");
    display.setCursor(2, 37); display.print("http://10.0.0.1");
    display.setCursor(2, 48); display.print("Open to configure");
    display.display(); return;
  }
  if (!wifiConn) {
    display.setCursor(4, 20); display.print("Connecting WiFi...");
    display.setCursor(4, 34); display.print(cfgSSID);
    display.display(); return;
  }
  if (!serverOnline) {
    display.setCursor(4, 18); display.print("Server offline!");
    display.setCursor(4, 30); display.print(cfgServerIP);
    display.setCursor(4, 46); display.print(WiFi.localIP());
    display.display(); return;
  }
  display.setCursor(2, 15); display.setTextSize(1); display.print("Active:");
  display.setCursor(2, 26); display.setTextSize(2);
  display.print(activeAntenna >= 0 ? ANT_NAMES[activeAntenna] : "All OFF");
  display.setTextSize(1);
  display.setCursor(2, 49);
  display.print("L:"); display.print(WiFi.localIP());
  display.setCursor(2, 57);
  display.print("S:"); display.print(cfgServerIP);
  display.print(serverOnline ? " OK" : " !!");
  display.display();
}

void drawSwitching(int idx) {
  display.clearDisplay();
  display.fillRect(0, 0, OLED_WIDTH, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK); display.setTextSize(1);
  display.setCursor(2, 2); display.print("ANT SWITCH CLIENT");
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(2, 18); display.print("Switching to:");
  display.setCursor(2, 30); display.setTextSize(2);
  display.print(ANT_NAMES[idx]);
  display.display();
}

// ─── WiFi scan → HTML <option> list ──────────────────────────────────────────
String buildScanOptions() {
  int n = WiFi.scanNetworks();
  String opts = "<option value=''>-- Select network --</option>";
  for (int i = 0; i < n; i++) {
    String ssid = WiFi.SSID(i);
    bool   sel  = (ssid == cfgSSID);
    opts += "<option value='" + ssid + "'" + (sel ? " selected" : "") + ">"
          + ssid + " (" + String(WiFi.RSSI(i)) + " dBm"
          + (WiFi.encryptionType(i) == WIFI_AUTH_OPEN ? ", open" : ", 🔒") + ")</option>";
  }
  WiFi.scanDelete();
  return opts;
}

// ─── Config portal HTML ───────────────────────────────────────────────────────
String buildPage(const String& msg = "") {
  // Run scan while building page
  String scanOpts = buildScanOptions();
  bool   useStatic = cfgClientIP.length() > 0;

  String h = R"(<!DOCTYPE html><html lang='en'><head>
<meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Antenna Client – WiFi Setup</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0f0f1a;color:#c9d1d9;font-family:Arial,sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:16px}
.card{background:#1a1a2e;border:1px solid #2a2a4a;border-radius:12px;padding:28px;width:100%;max-width:420px}
h1{color:#e94560;font-size:1.2rem;margin-bottom:2px}
.sub{font-size:.8rem;color:#555;margin-bottom:20px}
.sec{font-size:.7rem;text-transform:uppercase;color:#e94560;letter-spacing:.08em;margin:18px 0 8px;border-bottom:1px solid #2a2a4a;padding-bottom:4px}
label{display:block;font-size:.82rem;color:#aaa;margin-bottom:3px}
select,input[type=text],input[type=password]{width:100%;padding:9px 11px;background:#0f0f1a;border:1px solid #2a2a4a;border-radius:6px;color:#c9d1d9;font-size:.9rem;margin-bottom:12px}
select:focus,input:focus{outline:none;border-color:#e94560}
.hint{font-size:.75rem;color:#555;margin-top:-8px;margin-bottom:12px}
.chk{display:flex;align-items:center;gap:8px;margin-bottom:12px}
.chk input{width:auto;margin:0}
.chk label{margin:0;font-size:.85rem;color:#aaa}
.static-fields{border:1px solid #2a2a4a;border-radius:6px;padding:12px;margin-bottom:12px;background:#0f0f1a}
button{width:100%;padding:11px;background:#e94560;color:#fff;border:none;border-radius:6px;font-size:1rem;cursor:pointer;margin-top:4px}
button:hover{background:#c73652}
.btn2{background:#2a2a4a;margin-top:10px;font-size:.85rem}
.btn2:hover{background:#3a3a5a}
.msg{background:#1e3a1e;border:1px solid #2e6b2e;border-radius:6px;padding:10px;color:#7ec87e;font-size:.85rem;margin-bottom:16px;text-align:center}
.err{background:#3a1e1e;border-color:#6b2e2e;color:#c87e7e}
</style>
<script>
function toggleStatic(cb){
  document.getElementById('sf').style.display = cb.checked ? 'block' : 'none';
}
</script>
</head><body><div class='card'>
<h1>📡 Antenna Client Setup</h1>
<p class='sub'>Configure WiFi and server connection</p>)";

  if (msg.length()) {
    bool isErr = msg.startsWith("⚠");
    h += "<div class='msg" + String(isErr ? " err" : "") + "'>" + msg + "</div>";
  }

  h += "<form method='GET' action='/save'>";

  // WiFi section
  h += "<div class='sec'>WiFi Network</div>";
  h += "<label>Network (scanned)</label>";
  h += "<select name='ssid' onchange=\"document.getElementById('manssid').value=this.value\">" + scanOpts + "</select>";
  h += "<label>Or type SSID manually</label>";
  h += "<input type='text' id='manssid' name='manssid' value='" + cfgSSID + "' placeholder='Leave blank to use dropdown'>";
  h += "<label>Password</label>";
  h += "<input type='password' name='pass' value='" + cfgPass + "' placeholder='Leave blank if open network'>";

  // Static IP section
  h += "<div class='sec'>IP Address</div>";
  h += "<div class='chk'><input type='checkbox' id='useStatic' name='usestatic' value='1' onchange='toggleStatic(this)'";
  if (useStatic) h += " checked";
  h += "><label for='useStatic'>Use static IP (leave unchecked for DHCP)</label></div>";
  h += "<div id='sf' style='display:" + String(useStatic ? "block" : "none") + "'>";
  h += "<div class='static-fields'>";
  h += "<label>Client IP</label><input type='text' name='clientip' value='" + cfgClientIP + "' placeholder='e.g. 192.168.178.20'>";
  h += "<label>Gateway</label><input type='text' name='gateway' value='" + cfgGateway + "' placeholder='e.g. 192.168.178.1'>";
  h += "<label>Subnet Mask</label><input type='text' name='subnet' value='" + (cfgSubnet.length() ? cfgSubnet : "255.255.255.0") + "'>";
  h += "</div></div>";

  // Antenna names section
  h += "<div class='sec'>Antenna names</div>";
  for (int i = 0; i < 5; i++) {
    h += "<label>Antenna " + String(i+1) + "</label>";
    h += "<input type='text' name='ant" + String(i) + "' value='" + ANT_NAMES[i] +
         "' maxlength='10' placeholder='max 10 chars'>";
  }

  h += "<div class='sec'>Antenna Switch Server</div>";
  h += "<label>Server IP</label>";
  h += "<input type='text' name='serverip' value='" + cfgServerIP + "' placeholder='e.g. 192.168.178.15' required>";
  h += "<p class='hint'>IP of the antenna switch ESP32-C3</p>";

  h += "<button type='submit'>💾 Save &amp; Reboot</button>";
  h += "</form>";
  h += "<form method='GET' action='/reset'><button class='btn2' type='submit'>🔄 Reset to AP mode</button></form>";
  h += "<p style='font-size:.7rem;color:#333;text-align:center;margin-top:16px'>Latest code: "
       "<a href='https://github.com/WaarlandIT/HAM-Radio-Scripts' style='color:#444'>github.com/WaarlandIT/HAM-Radio-Scripts</a></p>";
  h += "</div></body></html>";
  return h;
}

// ─── Parse a single query-string parameter from a GET request line ────────────
String getParam(const String& req, const String& key) {
  String k = key + "=";
  int s = req.indexOf(k);
  if (s == -1) return "";
  s += k.length();
  int e = req.indexOf('&', s);
  if (e == -1) e = req.indexOf(' ', s);
  String val = (e == -1) ? req.substring(s) : req.substring(s, e);
  // URL decode %XX and +
  String out = "";
  for (int i = 0; i < (int)val.length(); i++) {
    if (val[i] == '+') { out += ' '; }
    else if (val[i] == '%' && i + 2 < (int)val.length()) {
      char hi = val[i+1], lo = val[i+2];
      auto h2 = [](char c) -> int {
        if (c>='0'&&c<='9') return c-'0';
        if (c>='A'&&c<='F') return c-'A'+10;
        if (c>='a'&&c<='f') return c-'a'+10;
        return 0;
      };
      out += (char)((h2(hi)<<4)|h2(lo));
      i += 2;
    } else { out += val[i]; }
  }
  return out;
}

void sendHtml(WiFiClient& cl, const String& body, int code = 200) {
  cl.print("HTTP/1.1 ");
  cl.print(code);
  cl.println(code == 200 ? " OK" : " Found");
  if (code == 302) { cl.println("Location: /"); cl.println("Content-Length: 0"); cl.println(); return; }
  cl.println("Content-Type: text/html; charset=utf-8");
  cl.println("Connection: close");
  cl.print("Content-Length: "); cl.println(body.length());
  cl.println();
  cl.print(body);
}

// ─── Config portal loop (blocking, runs only in AP mode) ──────────────────────
void runConfigPortal() {
  cfgServer.begin();
  drawScreen();

  while (true) {
    WiFiClient cl = cfgServer.available();
    if (!cl) { delay(5); continue; }

    String req = "";
    unsigned long t = millis();
    while (cl.connected() && millis() - t < 3000) {
      if (cl.available()) {
        char c = cl.read();
        if (c == '\n') break;
        if (c != '\r') req += c;
      }
    }
    while (cl.connected() && cl.available()) cl.read();   // drain headers

    if (req.startsWith("GET /save")) {
      // Prefer manually typed SSID over dropdown if filled in
      String manSSID = getParam(req, "manssid");
      String ssid    = manSSID.length() ? manSSID : getParam(req, "ssid");
      String pass    = getParam(req, "pass");
      String srvip   = getParam(req, "serverip");
      bool   useStatic = req.indexOf("usestatic=1") != -1;
      String clientip = useStatic ? getParam(req, "clientip") : "";
      String gw       = useStatic ? getParam(req, "gateway")  : "";
      String sn       = useStatic ? getParam(req, "subnet")   : "";

      String names[5];
      for (int i = 0; i < 5; i++) {
        names[i] = getParam(req, "ant" + String(i));
        if (names[i].isEmpty()) names[i] = "Output " + String(i+1);
        if (names[i].length() > 10) names[i] = names[i].substring(0, 10);
      }

      if (ssid.isEmpty() || srvip.isEmpty()) {
        sendHtml(cl, buildPage("⚠️ Network and Server IP are required."));
      } else {
        saveConfig(ssid, pass, srvip, clientip, gw, sn, names);
        sendHtml(cl,
          "<html><body style='background:#0f0f1a;color:#7ec87e;font-family:Arial;"
          "text-align:center;padding-top:60px'><h2>✅ Saved! Rebooting...</h2></body></html>");
        cl.stop(); delay(1200); ESP.restart();
      }

    } else if (req.startsWith("GET /reset")) {
      prefs.begin("antclient", false); prefs.putString("ssid", ""); prefs.end();
      sendHtml(cl,
        "<html><body style='background:#0f0f1a;color:#7ec87e;font-family:Arial;"
        "text-align:center;padding-top:60px'><h2>🔄 Resetting...</h2></body></html>");
      cl.stop(); delay(1200); ESP.restart();

    } else {
      sendHtml(cl, buildPage());
    }
    cl.stop();
  }
}

// ─── WiFi connect ─────────────────────────────────────────────────────────────
bool connectWiFi() {
  if (cfgClientIP.length()) {
    IPAddress ip, gw, sn, dns(8,8,8,8);
    ip.fromString(cfgClientIP);
    gw.fromString(cfgGateway);
    sn.fromString(cfgSubnet);
    WiFi.config(ip, gw, sn, dns);
  }
  WiFi.mode(WIFI_STA);
  WiFi.begin(cfgSSID.c_str(), cfgPass.c_str());

  unsigned long t = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t < 12000) {
    delay(300); drawScreen();
  }
  return WiFi.status() == WL_CONNECTED;
}

// ─── HTTP: switch antenna ─────────────────────────────────────────────────────
bool switchAntenna(int idx) {
  HTTPClient http;
  String url = "http://" + cfgServerIP + "/?antenna=" + (idx + 1);
  http.begin(url); http.setTimeout(3000);
  int code = http.GET(); http.end();
  return code == 200;
}

bool allOff() {
  HTTPClient http;
  http.begin("http://" + cfgServerIP + "/?antenna=0");
  http.setTimeout(3000);
  int code = http.GET(); http.end();
  return code == 200;
}

// ─── HTTP: poll /status ───────────────────────────────────────────────────────
void pollStatus() {
  if (WiFi.status() != WL_CONNECTED) { wifiConn = serverOnline = false; drawScreen(); return; }
  wifiConn = true;
  HTTPClient http;
  http.begin("http://" + cfgServerIP + "/status");
  http.setTimeout(2000);
  int code = http.GET();
  Serial.print("Poll HTTP code: "); Serial.println(code);
  if (code == 200) {
    serverOnline = true;
    String body = http.getString();
    Serial.print("Poll body: "); Serial.println(body);
    StaticJsonDocument<128> doc;
    DeserializationError err = deserializeJson(doc, body);
    if (err) {
      Serial.print("JSON error: "); Serial.println(err.c_str());
    } else {
      int pin = doc["antenna"] | -2;          // server uses "antenna", 1-based (0 = all off)
      Serial.print("Parsed antenna: "); Serial.println(pin);
      if (pin != -2) {
        activeAntenna = (pin > 0) ? pin - 1 : -1;   // convert to 0-based, -1 = all off
        Serial.print("activeAntenna set to: "); Serial.println(activeAntenna);
      }
    }
  } else {
    serverOnline = false;
  }
  http.end();
  drawScreen();
}

// ─── Buttons ──────────────────────────────────────────────────────────────────
bool offPrev = false;

void checkButtons() {
  // Antenna buttons 1–5
  for (int i = 0; i < 5; i++) {
    bool cur = (digitalRead(BTN_PINS[i]) == LOW);
    if (cur && !btnPrev[i]) {
      drawSwitching(i);
      if (switchAntenna(i)) activeAntenna = i;
      drawScreen();
    }
    btnPrev[i] = cur;
  }
  // All-OFF button
  bool offCur = (digitalRead(BTN_OFF) == LOW);
  if (offCur && !offPrev) {
    display.clearDisplay();
    display.fillRect(0, 0, OLED_WIDTH, 12, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK); display.setTextSize(1);
    display.setCursor(2, 2); display.print("ANT SWITCH CLIENT");
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(2, 28); display.setTextSize(2);
    display.print("All OFF");
    display.display();
    if (allOff()) activeAntenna = -1;
    drawScreen();
  }
  offPrev = offCur;
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  for (int i = 0; i < 5; i++) pinMode(BTN_PINS[i], INPUT_PULLUP);
  pinMode(BTN_OFF, INPUT_PULLUP);

  Wire.begin(8, 9);
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR))
    Serial.println("OLED init failed");
  display.clearDisplay(); display.display();

  loadConfig();

  if (cfgSSID.isEmpty()) {
    apMode = true;
    WiFi.mode(WIFI_AP);
    WiFi.softAPConfig(AP_IP, AP_GW, AP_SN);
    WiFi.softAP(AP_SSID);   // no password = open
    runConfigPortal();       // blocks until saved + reboot
    return;
  }

  drawScreen();
  wifiConn = connectWiFi();

  if (!wifiConn) {
    apMode = true;
    WiFi.mode(WIFI_AP);
    WiFi.softAPConfig(AP_IP, AP_GW, AP_SN);
    WiFi.softAP(AP_SSID);
    runConfigPortal();
    return;
  }

  // Start config web server in station mode too
  cfgServer.begin();

  pollStatus();
  drawScreen();
}

// ─── Station-mode config portal handler ───────────────────────────────────────
void handleConfigClient() {
  WiFiClient cl = cfgServer.available();
  if (!cl) return;

  String req = "";
  unsigned long t = millis();
  while (cl.connected() && millis() - t < 3000) {
    if (cl.available()) {
      char c = cl.read();
      if (c == '\n') break;
      if (c != '\r') req += c;
    }
  }
  while (cl.connected() && cl.available()) cl.read();

  if (req.startsWith("GET /save")) {
    String manSSID = getParam(req, "manssid");
    String ssid    = manSSID.length() ? manSSID : getParam(req, "ssid");
    String pass    = getParam(req, "pass");
    String srvip   = getParam(req, "serverip");
    bool   useStatic = req.indexOf("usestatic=1") != -1;
    String clientip = useStatic ? getParam(req, "clientip") : "";
    String gw       = useStatic ? getParam(req, "gateway")  : "";
    String sn       = useStatic ? getParam(req, "subnet")   : "";

    String names[5];
    for (int i = 0; i < 5; i++) {
      names[i] = getParam(req, "ant" + String(i));
      if (names[i].isEmpty()) names[i] = "Output " + String(i+1);
      if (names[i].length() > 10) names[i] = names[i].substring(0, 10);
    }

    if (ssid.isEmpty() || srvip.isEmpty()) {
      sendHtml(cl, buildPage("⚠️ Network and Server IP are required."));
    } else {
      saveConfig(ssid, pass, srvip, clientip, gw, sn, names);
      sendHtml(cl,
        "<html><body style='background:#0f0f1a;color:#7ec87e;font-family:Arial;"
        "text-align:center;padding-top:60px'><h2>✅ Saved! Rebooting...</h2></body></html>");
      cl.stop(); delay(1200); ESP.restart();
    }
  } else if (req.startsWith("GET /reset")) {
    prefs.begin("antclient", false); prefs.putString("ssid", ""); prefs.end();
    sendHtml(cl,
      "<html><body style='background:#0f0f1a;color:#7ec87e;font-family:Arial;"
      "text-align:center;padding-top:60px'><h2>🔄 Resetting to AP mode...</h2></body></html>");
    cl.stop(); delay(1200); ESP.restart();
  } else {
    sendHtml(cl, buildPage());
  }
  cl.stop();
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  if (now - lastBtn >= 20) { checkButtons(); lastBtn = now; }

  handleConfigClient();   // serve config portal in station mode

  if (now - lastPoll >= POLL_INTERVAL) {
    pollStatus();
    lastPoll = now;

    if (WiFi.status() != WL_CONNECTED) {
      wifiConn = serverOnline = false; drawScreen();
      wifiConn = connectWiFi();
      if (!wifiConn) {
        apMode = true;
        WiFi.mode(WIFI_AP);
        WiFi.softAPConfig(AP_IP, AP_GW, AP_SN);
        WiFi.softAP(AP_SSID);
        runConfigPortal();
      }
    }
  }
}
