#!/usr/bin/env python3
"""
Remotey macOS Agent Server
Enables Windows (or remote clients) to control this Mac over Tailscale/LAN.
Provides pure HTTP endpoints matching the Remotey protocol:
  GET  /status
  GET  /screenshot
  POST /click
  POST /move
  POST /type
  POST /key
  POST /hotkey
  POST /scroll
  POST /run
"""

import http.server
import json
import os
import subprocess
import tempfile
import time
import ctypes
from ctypes import c_double, c_uint32, c_int32, Structure, c_void_p

PORT = int(os.environ.get("REMOTEY_PORT", 7777))

# CoreGraphics C binding
class CGPoint(Structure):
    _fields_ = [("x", c_double), ("y", c_double)]

try:
    cg = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    cg.CGEventCreate.restype = c_void_p
    cg.CGEventCreate.argtypes = [c_void_p]
    cg.CGEventGetLocation.restype = CGPoint
    cg.CGEventGetLocation.argtypes = [c_void_p]

    cg.CGEventCreateMouseEvent.restype = c_void_p
    cg.CGEventCreateMouseEvent.argtypes = [c_void_p, c_uint32, CGPoint, c_uint32]
    cg.CGEventPost.restype = None
    cg.CGEventPost.argtypes = [c_uint32, c_void_p]

    cg.CGEventCreateScrollWheelEvent.restype = c_void_p
    cg.CGEventCreateScrollWheelEvent.argtypes = [c_void_p, c_uint32, c_uint32, c_int32]

    cg.CGMainDisplayID.restype = c_uint32
except Exception as e:
    cg = None

# CG Event Constants
kCGHIDEventTap = 0
kCGEventLeftMouseDown = 1
kCGEventLeftMouseUp = 2
kCGEventRightMouseDown = 3
kCGEventRightMouseUp = 4
kCGEventMouseMoved = 5
kCGMouseButtonLeft = 0
kCGMouseButtonRight = 1

def get_screen_bounds():
    if not cg:
        return 1920, 1080
    mid = cg.CGMainDisplayID()
    return cg.CGDisplayPixelsWide(mid), cg.CGDisplayPixelsHigh(mid)

def get_cursor_pos():
    if not cg:
        return 0, 0
    evt = cg.CGEventCreate(None)
    loc = cg.CGEventGetLocation(evt)
    return int(loc.x), int(loc.y)

def move_cursor(x, y):
    if cg:
        pt = CGPoint(float(x), float(y))
        evt = cg.CGEventCreateMouseEvent(None, kCGEventMouseMoved, pt, kCGMouseButtonLeft)
        cg.CGEventPost(kCGHIDEventTap, evt)

def click_mouse(x, y, button="left", count=1):
    if not cg:
        return
    pt = CGPoint(float(x), float(y))
    down_type = kCGEventLeftMouseDown if button != "right" else kCGEventRightMouseDown
    up_type = kCGEventLeftMouseUp if button != "right" else kCGEventRightMouseUp
    btn = kCGMouseButtonLeft if button != "right" else kCGMouseButtonRight

    move_cursor(x, y)
    time.sleep(0.02)
    for _ in range(count):
        d = cg.CGEventCreateMouseEvent(None, down_type, pt, btn)
        cg.CGEventPost(kCGHIDEventTap, d)
        time.sleep(0.02)
        u = cg.CGEventCreateMouseEvent(None, up_type, pt, btn)
        cg.CGEventPost(kCGHIDEventTap, u)
        time.sleep(0.02)

def scroll_wheel(amount):
    if cg:
        # amount > 0 is scroll up, < 0 is scroll down
        evt = cg.CGEventCreateScrollWheelEvent(None, 0, 1, int(amount))
        cg.CGEventPost(kCGHIDEventTap, evt)

def type_text(text):
    # Safe AppleScript keystroke
    escaped = text.replace('\\', '\\\\').replace('"', '\\"')
    subprocess.run(["osascript", "-e", f'tell application "System Events" to keystroke "{escaped}"'], capture_output=True)

def send_key(key):
    key_map = {
        "enter": "key code 36",
        "return": "key code 36",
        "tab": "key code 48",
        "esc": "key code 53",
        "escape": "key code 53",
        "space": "key code 49",
        "backspace": "key code 51",
        "delete": "key code 51",
        "up": "key code 126",
        "down": "key code 125",
        "left": "key code 123",
        "right": "key code 124"
    }
    k = key.lower()
    cmd = key_map.get(k, f'keystroke "{key}"')
    subprocess.run(["osascript", "-e", f'tell application "System Events" to {cmd}'], capture_output=True)

def send_hotkey(keys):
    # e.g. "cmd+c", "ctrl+c", "cmd+space"
    parts = [p.strip().lower() for p in keys.split("+")]
    char = parts[-1]
    modifiers = parts[:-1]
    mod_str = []
    for m in modifiers:
        if m in ("cmd", "command"): mod_str.append("command down")
        elif m in ("ctrl", "control"): mod_str.append("control down")
        elif m in ("alt", "opt", "option"): mod_str.append("option down")
        elif m == "shift": mod_str.append("shift down")

    if mod_str:
        using_clause = f" using {{{', '.join(mod_str)}}}"
    else:
        using_clause = ""

    subprocess.run(["osascript", "-e", f'tell application "System Events" to keystroke "{char}"{using_clause}'], capture_output=True)

def get_frontmost_app():
    try:
        res = subprocess.run(["osascript", "-e", 'tell application "System Events" to get name of first application process whose frontmost is true'], capture_output=True, text=True, timeout=1)
        return res.stdout.strip() or "Finder"
    except Exception:
        return "Unknown"

class RemoteyHandler(http.server.BaseHTTPRequestHandler):
    def send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors()
        self.end_headers()

    def do_GET(self):
        if self.path in ("/status", "/info"):
            w, h = get_screen_bounds()
            cx, cy = get_cursor_pos()
            app = get_frontmost_app()
            data = {
                "ok": True,
                "platform": "darwin",
                "width": w,
                "height": h,
                "cursorX": cx,
                "cursorY": cy,
                "activeWindow": app,
                "host": os.uname().nodename,
                "user": os.environ.get("USER", "")
            }
            res = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(res)))
            self.send_cors()
            self.end_headers()
            self.wfile.write(res)

        elif self.path == "/screenshot":
            tmp_path = f"/tmp/remotey_capture_{int(time.time() * 1000)}.png"
            try:
                # High-speed native macOS screencapture
                subprocess.run(["screencapture", "-x", "-C", tmp_path], check=True)
                with open(tmp_path, "rb") as f:
                    png_data = f.read()

                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(png_data)))
                self.send_cors()
                self.end_headers()
                self.wfile.write(png_data)
            except Exception as e:
                err_resp = str(e).encode("utf-8")
                self.send_response(500)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Content-Length", str(len(err_resp)))
                self.send_cors()
                self.end_headers()
                self.wfile.write(err_resp)
            finally:
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            payload = json.loads(body)
        except Exception:
            payload = {}

        if self.path == "/click":
            x = payload.get("x", 0)
            y = payload.get("y", 0)
            btn = payload.get("button", "left")
            count = payload.get("count", 1)
            click_mouse(x, y, btn, count)
            resp = json.dumps({"ok": True}).encode("utf-8")

        elif self.path == "/move":
            x = payload.get("x", 0)
            y = payload.get("y", 0)
            move_cursor(x, y)
            resp = json.dumps({"ok": True}).encode("utf-8")

        elif self.path == "/type":
            text = payload.get("text", "")
            type_text(text)
            resp = json.dumps({"ok": True}).encode("utf-8")

        elif self.path in ("/key", "/press"):
            key = payload.get("key", "")
            send_key(key)
            resp = json.dumps({"ok": True}).encode("utf-8")

        elif self.path == "/hotkey":
            keys = payload.get("keys", "") or payload.get("key", "")
            send_hotkey(keys)
            resp = json.dumps({"ok": True}).encode("utf-8")

        elif self.path == "/scroll":
            amt = payload.get("amount", -200)
            scroll_wheel(amt)
            resp = json.dumps({"ok": True}).encode("utf-8")

        elif self.path == "/run":
            cmd = payload.get("command", "")
            try:
                res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
                resp = json.dumps({"ok": True, "stdout": res.stdout, "stderr": res.stderr, "exitCode": res.returncode}).encode("utf-8")
            except Exception as e:
                resp = json.dumps({"ok": False, "error": str(e)}).encode("utf-8")
        else:
            self.send_response(404)
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(resp)))
        self.send_cors()
        self.end_headers()
        self.wfile.write(resp)

    def log_message(self, format, *args):
        # Terse logging
        print(f"[{time.strftime('%H:%M:%S')}] {args[0]} -> {args[1]}")

def run_server():
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), RemoteyHandler)
    print("==========================================================")
    print(f" 🚀 Remotey macOS Agent Starting on port {PORT}...")
    print("==========================================================")
    print(f"[SUCCESS] Listening on 0.0.0.0:{PORT} (ALL INTERFACES)")
    print("Ready for autonomous commands from Windows / Remote PC!\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down Remotey agent.")
        server.server_close()

if __name__ == "__main__":
    run_server()
