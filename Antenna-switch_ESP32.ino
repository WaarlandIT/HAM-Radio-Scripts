/*
 * ESP32-C3 Super Mini – 5 GPIO Antenna Switch
 * WiFi config via captive Access Point portal
 * Settings saved to NVS (Preferences)
 * Arduino IDE – ESP32 Arduino core v2 / v3
 *
 * First boot (or after reset of settings):
 *   Connect to AP  "AS01"  (no password)
 *   Browse to      http://192.168.4.1
 *   Select SSID, enter password, optional static IP and save.
 *   Board reboots and connects to your network.
 *
 * To re-enter config mode: hold GPIO 9 (BOOT button) LOW for 3 s at runtime,
 * or hold BOOT at power-on to erase saved config.
 */

#include <WiFi.h>
#include <Preferences.h>

// ─── Structs (must be declared before use in Arduino IDE) ────────────────────
struct NetCfg { String ssid, pass, ip, gw; bool staticIP; };
struct HttpReq { String method, path, body; };

// ─── GPIO pins (avoid strapping pins 2, 8, 9) ────────────────────────────────
const uint8_t GPIO_PINS[5] = {4, 5, 6, 7, 8};
const char*   PIN_NAMES[5] = {"Antenna 1", "Antenna 2", "Antenna 3", "Antenna 4", "Antenna 5"};

// ─── AP credentials ───────────────────────────────────────────────────────────
const char* AP_SSID = "AS01";
const char* AP_PASS = "";                // open AP, no password

// ─── Config-reset button ──────────────────────────────────────────────────────
const uint8_t CFG_BTN = 9;              // BOOT button on ESP32-C3 Super Mini

// ─── Globals ──────────────────────────────────────────────────────────────────
Preferences prefs;
WiFiServer  server(80);
int  activePin  = -1;
bool apMode     = false;

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

// ─── Read/save/clear config ───────────────────────────────────────────────────
NetCfg loadCfg() {
  prefs.begin("netcfg", true);
  NetCfg c;
  c.ssid     = prefs.getString("ssid", "");
  c.pass     = prefs.getString("pass", "");
  c.ip       = prefs.getString("ip",   "");
  c.gw       = prefs.getString("gw",   "");
  c.staticIP = prefs.getBool("static", false);
  prefs.end();
  Serial.println("Loaded config – SSID: '" + c.ssid + "' static: " + String(c.staticIP));
  return c;
}
void saveCfg(const NetCfg& c) {
  prefs.begin("netcfg", false);
  prefs.putString("ssid",   c.ssid);
  prefs.putString("pass",   c.pass);
  prefs.putString("ip",     c.ip);
  prefs.putString("gw",     c.gw);
  prefs.putBool  ("static", c.staticIP);
  prefs.end();
  Serial.println("Saved config – SSID: " + c.ssid + " static: " + String(c.staticIP));
}
void clearCfg() {
  prefs.begin("netcfg", false);
  prefs.clear();
  prefs.end();
}

// ─── URL decode helper ────────────────────────────────────────────────────────
String urlDecode(const String& s) {
  String out;
  for (int i = 0; i < (int)s.length(); i++) {
    if (s[i] == '+') { out += ' '; }
    else if (s[i] == '%' && i + 2 < (int)s.length()) {
      char hi = s[i+1], lo = s[i+2];
      auto h2i = [](char c) -> int {
        if (c>='0'&&c<='9') return c-'0';
        if (c>='A'&&c<='F') return c-'A'+10;
        if (c>='a'&&c<='f') return c-'a'+10;
        return 0;
      };
      out += (char)(h2i(hi)*16 + h2i(lo));
      i += 2;
    } else { out += s[i]; }
  }
  return out;
}

// ─── Parse a query string value ───────────────────────────────────────────────
String qval(const String& body, const String& key) {
  int p = body.indexOf(key + "=");
  if (p == -1) return "";
  p += key.length() + 1;
  int e = body.indexOf('&', p);
  return urlDecode(e == -1 ? body.substring(p) : body.substring(p, e));
}

// ─── Parse IP string into IPAddress ──────────────────────────────────────────
bool parseIP(const String& s, IPAddress& out) {
  return out.fromString(s);
}

// ─── HTML head ────────────────────────────────────────────────────────────────
String htmlHead(const String& title) {
  return "<!DOCTYPE html><html lang='en'><head>"
    "<meta charset='UTF-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>" + title + "</title><style>"
    "*{box-sizing:border-box;margin:0;padding:0}"
    "body{font-family:Arial,sans-serif;background:#1a1a2e;color:#eee;"
         "display:flex;flex-direction:column;align-items:center;padding:30px 16px}"
    "h1{margin-bottom:6px;font-size:1.4rem;color:#e94560}"
    "p{margin-bottom:16px;font-size:.82rem;color:#aaa}"
    "p.sub{margin-bottom:24px}"
    ".grid{display:grid;gap:12px;width:100%;max-width:360px}"
    "a.btn,button.btn{display:flex;justify-content:space-between;align-items:center;"
      "padding:15px 18px;border-radius:10px;text-decoration:none;"
      "font-size:1rem;transition:filter .2s;border:none;cursor:pointer;width:100%}"
    "a.off,button.off{background:#2a2a4a;color:#ccc}"
    "a.on ,button.on {background:#e94560;color:#fff;box-shadow:0 0 14px #e9456077}"
    "a:hover,button:hover{filter:brightness(1.25)}"
    ".badge{font-size:.7rem;padding:3px 8px;border-radius:20px;background:rgba(255,255,255,.15)}"
    "a.alloff{margin-top:18px;padding:11px 30px;border:2px solid #555;"
      "border-radius:10px;color:#aaa;text-decoration:none;font-size:.9rem}"
    "a.alloff:hover{border-color:#e94560;color:#e94560}"
    ".status{margin-top:16px;font-size:.78rem;color:#777}"
    "form.cfg{display:grid;gap:10px;width:100%;max-width:360px;margin-top:10px}"
    "form.cfg label{font-size:.82rem;color:#aaa}"
    "form.cfg input{padding:10px 12px;border-radius:8px;border:1px solid #444;"
      "background:#2a2a4a;color:#eee;font-size:.95rem;width:100%}"
    "form.cfg input:focus{outline:none;border-color:#e94560}"
    "form.cfg button{padding:13px;border-radius:10px;border:none;"
      "background:#e94560;color:#fff;font-size:1rem;cursor:pointer;margin-top:6px}"
    "form.cfg button:hover{filter:brightness(1.2)}"
    ".note{margin-top:20px;font-size:.75rem;color:#555;text-align:center}"
    "</style></head><body>";
}

// ─── WiFi scan ────────────────────────────────────────────────────────────────
String buildScanOptions(const String& selected) {
  int n = WiFi.scanNetworks();
  if (n <= 0) return "<option value=''>-- No networks found --</option>";

  // Sort by RSSI descending
  int idx[n];
  for (int i = 0; i < n; i++) idx[i] = i;
  for (int i = 0; i < n-1; i++)
    for (int j = i+1; j < n; j++)
      if (WiFi.RSSI(idx[j]) > WiFi.RSSI(idx[i])) { int t=idx[i]; idx[i]=idx[j]; idx[j]=t; }

  String opts = "";
  for (int i = 0; i < n; i++) {
    int k       = idx[i];
    String ssid = WiFi.SSID(k);
    int rssi    = WiFi.RSSI(k);
    bool enc    = (WiFi.encryptionType(k) != WIFI_AUTH_OPEN);
    String bar  = rssi > -60 ? "▂▄▆█" : rssi > -75 ? "▂▄▆_" : rssi > -85 ? "▂▄__" : "▂___";
    String sel  = (ssid == selected) ? " selected" : "";
    opts += "<option value='" + ssid + "'" + sel + ">"
            + bar + "  " + ssid + (enc ? "  🔒" : "")
            + "  (" + rssi + " dBm)</option>";
  }
  WiFi.scanDelete();
  return opts;
}

// ─── Config portal page ───────────────────────────────────────────────────────
String buildConfigPage(const String& msg = "") {
  NetCfg c = loadCfg();
  String scanOpts = buildScanOptions(c.ssid);
  String h = htmlHead("Antenna Switch – WiFi Setup");
  h += "<h1>&#9889; WiFi Configuration</h1>"
       "<p class='sub'>Antenna Switch &nbsp;|&nbsp; PA3RPW 2026</p>";
  if (msg.length()) h += "<p style='color:#e94560'>" + msg + "</p>";
  String chk = c.staticIP ? " checked" : "";
  String dsp = c.staticIP ? "grid" : "none";
  h += "<form class='cfg' method='POST' action='/save'>"
       "<label>WiFi Network</label>"
       "<select name='ssid' required style='"
         "padding:10px 12px;border-radius:8px;border:1px solid #444;"
         "background:#2a2a4a;color:#eee;font-size:.95rem;width:100%'>"
       "<option value=''>-- Select network --</option>"
       + scanOpts +
       "</select>"
       "<label>Password</label>"
       "<input name='pass' type='password' placeholder='WiFi password' value='" + c.pass + "'>"
       "<label style='display:flex;align-items:center;gap:10px;cursor:pointer'>"
       "<input type='checkbox' name='useStatic' id='useStatic' value='1'" + chk +
       " onchange=\"document.getElementById('staticFields').style.display="
       "this.checked?'grid':'none'\" style='width:18px;height:18px;accent-color:#e94560'>"
       "<span>Use static IP</span>"
       "</label>"
       "<div id='staticFields' style='display:" + dsp + ";grid-gap:10px'>"
       "<label>Static IP  <small style='color:#666'>(e.g. 192.168.178.15)</small></label>"
       "<input name='ip' type='text' placeholder='192.168.1.100' value='" + c.ip + "'>"
       "<label>Gateway  <small style='color:#666'>(e.g. 192.168.178.1)</small></label>"
       "<input name='gw' type='text' placeholder='192.168.1.1' value='" + c.gw + "'>"
       "</div>"
       "<button type='submit'>Save &amp; Connect</button>"
       "</form>"
       "<p class='note'>Subnet fixed at 255.255.255.0 &nbsp;|&nbsp; DNS: 8.8.8.8<br>"
       "<a href='/config' style='color:#555;font-size:.75rem'>&#8635; Rescan networks</a></p>"
       "</body></html>";
  return h;
}

// ─── Help page ────────────────────────────────────────────────────────────────
String buildHelpPage() {
  String h = htmlHead("Antenna Switch – Help");
  h += "<h1>&#9889; Antenna Switch Help</h1>"
       "<p class='sub'>API &amp; usage documentation &nbsp;|&nbsp; PA3RPW 2026</p>"

       // Web interface
       "<div style='width:100%;max-width:560px'>"
       "<h2 style='color:#e94560;font-size:1rem;margin:18px 0 8px'>&#127760; Web Interface</h2>"
       "<p>Open <code style='color:#aaa'>http://&lt;ip&gt;/</code> in any browser to access "
       "the antenna switch control panel. Click an antenna button to activate it. "
       "Only one antenna can be active at a time. Use <b>All OFF</b> to deactivate all outputs.</p>"

       // Switch antenna
       "<h2 style='color:#e94560;font-size:1rem;margin:18px 0 8px'>&#128268; Switch Antenna</h2>"
       "<p>Switch to a specific antenna via GET request:</p>"
       "<pre style='background:#121220;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>GET /?antenna=N</pre>"
       "<p><code style='color:#aaa'>N</code> = antenna number <b>1–5</b>, or <b>0</b> to turn all off.</p>"
       "<p style='margin-top:6px'>Examples:</p>"
       "<pre style='background:#12122a;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>"
       "http://&lt;ip&gt;/?antenna=1   → activate Antenna 1\n"
       "http://&lt;ip&gt;/?antenna=3   → activate Antenna 3\n"
       "http://&lt;ip&gt;/?antenna=0   → all OFF</pre>"
       "<p>JSON response:</p>"
       "<pre style='background:#12122a;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>"
       "{\"status\":\"ok\",\"antenna\":1,\"name\":\"Antenna 1\"}</pre>"

       // Status
       "<h2 style='color:#e94560;font-size:1rem;margin:18px 0 8px'>&#128202; Get Status</h2>"
       "<p>Query the currently active antenna:</p>"
       "<pre style='background:#12122a;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>GET /status</pre>"
       "<p>JSON response (antenna active):</p>"
       "<pre style='background:#12122a;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>"
       "{\"status\":\"ok\",\"antenna\":2,\"name\":\"Antenna 2\",\"active\":true}</pre>"
       "<p>JSON response (all off):</p>"
       "<pre style='background:#12122a;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>"
       "{\"status\":\"ok\",\"antenna\":0,\"name\":\"off\",\"active\":false}</pre>"

       // WiFi config
       "<h2 style='color:#e94560;font-size:1rem;margin:18px 0 8px'>&#9881; WiFi Configuration</h2>"
       "<p>Open <code style='color:#aaa'>http://&lt;ip&gt;/config</code> to change WiFi settings. "
       "DHCP is the default. Enable <b>Use static IP</b> to assign a fixed address.</p>"
       "<p style='margin-top:6px'>To reset WiFi config and return to AP mode:</p>"
       "<ul style='color:#aaa;font-size:.82rem;margin:6px 0 0 18px;line-height:1.8'>"
       "<li>Hold the <b>BOOT</b> button for 3 seconds at runtime, <b>or</b></li>"
       "<li>Hold <b>BOOT</b> while powering on the board</li>"
       "</ul>"

       // AP mode
       "<h2 style='color:#e94560;font-size:1rem;margin:18px 0 8px'>&#128225; Access Point Mode</h2>"
       "<p>When no WiFi is configured (or connection fails), the board starts its own AP:</p>"
       "<ul style='color:#aaa;font-size:.82rem;margin:6px 0 0 18px;line-height:1.8'>"
       "<li>SSID: <b>AS01</b> &nbsp;(open, no password)</li>"
       "<li>Config portal: <b>http://192.168.4.1/config</b></li>"
       "<li>Antenna control is also available via AP at <b>http://192.168.4.1/</b></li>"
       "</ul>"

       // curl examples
       "<h2 style='color:#e94560;font-size:1rem;margin:18px 0 8px'>&#9654; curl Examples</h2>"
       "<pre style='background:#12122a;padding:12px;border-radius:8px;font-size:.82rem;"
            "color:#aaa;overflow-x:auto;margin:6px 0'>"
       "curl http://&lt;ip&gt;/?antenna=2\n"
       "curl http://&lt;ip&gt;/?antenna=0\n"
       "curl http://&lt;ip&gt;/status</pre>"

       "<p style='margin-top:24px;text-align:center'>"
       "<a href='/' style='color:#e94560;font-size:.85rem;text-decoration:none'>"
       "&#8592; Back to Antenna Switch</a></p>"
       "<p style='margin-top:24px;font-size:.75rem;color:#444;text-align:center'>"
       "Latest code available on GitHub:<br>"
       "<a href='https://github.com/WaarlandIT/HAM-Radio-Scripts' target='_blank' "
       "style='color:#555;text-decoration:none'>"
       "&#128279; github.com/WaarlandIT/HAM-Radio-Scripts</a></p>"
       "</div></body></html>";
  return h;
}
String buildMainPage() {
  String h = htmlHead("Antenna Switch Control");
  h += "<h1>&#9889; Antenna Switch Control</h1>"
       "<p class='sub'>Switch between antenna's</p>"
       "<div class='grid'>";
  for (int i = 0; i < 5; i++) {
    bool on = (activePin == i);
    h += "<a class='btn " + String(on?"on":"off") + "' href='/set?pin=" + i + "'>"
         "<span>" + PIN_NAMES[i] + "</span>"
         "<span class='badge'>" + (on?"ON":"OFF") + "</span></a>";
  }
  h += "</div>"
       "<a class='alloff' href='/off'>&#9632; All OFF</a>"
       "<p class='status'>Active: " +
       (activePin >= 0 ? String(PIN_NAMES[activePin]) : "None") +
       "</p>"
       "<p style='margin-top:28px'>"
       "<a href='/config' style='font-size:.75rem;color:#555;text-decoration:none'>"
       "&#9881; WiFi settings</a>"
       " &nbsp;|&nbsp; "
       "<a href='/help' style='font-size:.75rem;color:#555;text-decoration:none'>"
       "&#10067; Help &amp; API</a></p>"
       "<p style='margin-top:16px;font-size:.72rem;color:#444;text-align:center'>"
       "API: <code style='color:#666'>/?antenna=1..5</code> &nbsp;|&nbsp;"
       "<code style='color:#666'>/?antenna=0</code> = off &nbsp;|&nbsp;"
       "<code style='color:#666'>/status</code></p>"
       "<p>by: PA3RPW 2026</p>"
       "</body></html>";
  return h;
}

// ─── HTTP send helpers ────────────────────────────────────────────────────────
void sendHTML(WiFiClient& cl, const String& body) {
  cl.println("HTTP/1.1 200 OK");
  cl.println("Content-Type: text/html");
  cl.println("Connection: close");
  cl.print("Content-Length: "); cl.println(body.length());
  cl.println();
  cl.print(body);
}
void sendRedirect(WiFiClient& cl, const String& loc = "/") {
  cl.println("HTTP/1.1 303 See Other");
  cl.print("Location: "); cl.println(loc);
  cl.println("Connection: close");
  cl.println();
}

// ─── Read full HTTP request (headers + body) ──────────────────────────────────
HttpReq readRequest(WiFiClient& cl) {
  HttpReq r;
  unsigned long t = millis();
  String line;
  int contentLen = 0;
  bool firstLine = true;

  while (cl.connected() && millis() - t < 3000) {
    if (!cl.available()) { delay(1); continue; }
    char c = cl.read();
    if (c == '\n') {
      line.trim();
      if (firstLine) {
        int s1 = line.indexOf(' '), s2 = line.indexOf(' ', s1+1);
        r.method = line.substring(0, s1);
        r.path   = line.substring(s1+1, s2);
        firstLine = false;
      } else {
        String ll = line; ll.toLowerCase();
        if (ll.startsWith("content-length:"))
          contentLen = line.substring(line.indexOf(':') + 1).toInt();
        else if (line.length() == 0)
          break;
      }
      line = "";
    } else if (c != '\r') { line += c; }
  }

  if (r.method == "POST" && contentLen > 0) {
    t = millis();
    while ((int)r.body.length() < contentLen && cl.connected() && millis()-t < 2000)
      if (cl.available()) r.body += (char)cl.read();
  }
  return r;
}

// ─── Route handler ────────────────────────────────────────────────────────────
void handleClient(WiFiClient& cl) {
  HttpReq req = readRequest(cl);
  if (req.method.length() == 0) { cl.stop(); return; }

  if (req.method == "POST" && req.path == "/save") {
    NetCfg nc;
    nc.ssid     = qval(req.body, "ssid");
    nc.pass     = qval(req.body, "pass");
    nc.ip       = qval(req.body, "ip");
    nc.gw       = qval(req.body, "gw");
    nc.staticIP = (qval(req.body, "useStatic") == "1");

    IPAddress testIP, testGW;
    if (nc.ssid.length() == 0) {
      sendHTML(cl, buildConfigPage("&#9888; Please select a network."));
    } else if (nc.staticIP && (!parseIP(nc.ip, testIP) || !parseIP(nc.gw, testGW))) {
      sendHTML(cl, buildConfigPage("&#9888; Invalid static IP or gateway format."));
    } else {
      saveCfg(nc);
      String ok = htmlHead("Saved") +
        "<h1 style='color:#4caf50'>&#10003; Saved!</h1>"
        "<p style='margin-top:16px'>Rebooting and connecting to <b>" + nc.ssid + "</b>…</p>" +
        (nc.staticIP
          ? "<p>After ~5 s open: <b>http://" + nc.ip + "</b></p>"
          : "<p>IP assigned by DHCP – check your router for the address.</p>") +
        "</body></html>";
      sendHTML(cl, ok);
      cl.stop();
      delay(1500);
      ESP.restart();
    }
    cl.stop(); return;
  }

  if (req.path == "/config" || req.path.startsWith("/config?")) {
    sendHTML(cl, buildConfigPage());
    cl.stop(); return;
  }

  if (req.path == "/help") {
    sendHTML(cl, buildHelpPage());
    cl.stop(); return;
  }

  if (req.path.startsWith("/set")) {
    // Web UI button: /set?pin=N
    int p = req.path.indexOf("pin=");
    if (p != -1) {
      int idx = req.path.charAt(p+4) - '0';
      if (idx >= 0 && idx < 5) setPin(idx);
    }
    sendRedirect(cl);
  } else if (req.path.startsWith("/off")) {
    allOff();
    sendRedirect(cl);
  } else if (req.path.indexOf("antenna=") != -1) {
    // API: /?antenna=1..5  or  /api?antenna=1..5
    int p   = req.path.indexOf("antenna=");
    int num = req.path.substring(p + 8).toInt();  // 1-based
    String json;
    if (num >= 1 && num <= 5) {
      setPin(num - 1);
      json = "{\"status\":\"ok\",\"antenna\":" + String(num) +
             ",\"name\":\"" + String(PIN_NAMES[num-1]) + "\"}";
    } else if (num == 0) {
      allOff();
      json = "{\"status\":\"ok\",\"antenna\":0,\"name\":\"off\"}";
    } else {
      json = "{\"status\":\"error\",\"message\":\"antenna must be 0-5\"}";
    }
    cl.println("HTTP/1.1 200 OK");
    cl.println("Content-Type: application/json");
    cl.println("Connection: close");
    cl.print("Content-Length: "); cl.println(json.length());
    cl.println();
    cl.print(json);
  } else if (req.path == "/status" || req.path.startsWith("/status?")) {
    // API: /status  – returns current active antenna as JSON
    String json;
    if (activePin >= 0) {
      json = "{\"status\":\"ok\",\"antenna\":" + String(activePin + 1) +
             ",\"name\":\"" + String(PIN_NAMES[activePin]) + "\",\"active\":true}";
    } else {
      json = "{\"status\":\"ok\",\"antenna\":0,\"name\":\"off\",\"active\":false}";
    }
    cl.println("HTTP/1.1 200 OK");
    cl.println("Content-Type: application/json");
    cl.println("Connection: close");
    cl.print("Content-Length: "); cl.println(json.length());
    cl.println();
    cl.print(json);
  } else {
    sendHTML(cl, buildMainPage());
  }
  cl.stop();
}

// ─── Start AP portal ──────────────────────────────────────────────────────────
void startAP() {
  apMode = true;
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.println("AP started: " + String(AP_SSID));
  Serial.print("Config portal: http://");
  Serial.println(WiFi.softAPIP());
  server.begin();
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(2000);

  for (int i = 0; i < 5; i++) {
    pinMode(GPIO_PINS[i], OUTPUT);
    digitalWrite(GPIO_PINS[i], LOW);
  }

  pinMode(CFG_BTN, INPUT_PULLUP);

  if (digitalRead(CFG_BTN) == LOW) {
    Serial.println("Config reset requested");
    clearCfg();
  }

  NetCfg c = loadCfg();

  if (c.ssid.length() == 0) {
    Serial.println("No config found – starting setup portal");
    startAP();
    return;
  }

  if (c.staticIP && c.ip.length() > 0 && c.gw.length() > 0) {
    IPAddress ip, gw, sn(255,255,255,0), dns(8,8,8,8);
    parseIP(c.ip, ip);
    parseIP(c.gw, gw);
    if (!WiFi.config(ip, gw, sn, dns))
      Serial.println("Static IP config failed");
    else
      Serial.println("Using static IP: " + c.ip);
  } else {
    WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE);
    Serial.println("Using DHCP");
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(c.ssid.c_str(), c.pass.c_str());
  Serial.print("Connecting to " + c.ssid);

  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500); Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected! http://" + WiFi.localIP().toString());
    if (!c.staticIP)
      Serial.println("DHCP assigned IP: " + WiFi.localIP().toString());
    server.begin();
  } else {
    Serial.println("\nConnection failed – falling back to setup portal");
    startAP();
  }
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  if (digitalRead(CFG_BTN) == LOW) {
    unsigned long held = millis();
    while (digitalRead(CFG_BTN) == LOW) {
      if (millis() - held > 3000) {
        Serial.println("Long press – clearing config");
        clearCfg();
        delay(500);
        ESP.restart();
      }
    }
  }

  WiFiClient cl = server.available();
  if (!cl) return;
  handleClient(cl);
}
