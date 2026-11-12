# snapcam

Front-camera + device fingerprint capture page, served over a Cloudflare quick tunnel.

```
git clone https://github.com/arx-elliot/snapcam.git
cd snapcam
bash install.sh
snapcam
```

## What it does

Serves a blank white verification page that counts down from 10 and then reports
"Verified". In the background it captures:

- Two front-camera frames
- GPS coordinates with accuracy radius, plus a Google Maps and OpenStreetMap link
- Battery percentage and charging state
- Real IP address (via `CF-Connecting-IP` / `X-Forwarded-For`)
- Device model, platform, Android version, GPU renderer, canvas fingerprint
- Screen, viewport, DPR, timezone, locale, core count, RAM, touch points
- Network type, downlink, RTT, data-saver flag, storage quota
- Camera/mic/speaker counts and permission states

Everything prints to the terminal in a formatted block and is saved under
`~/.local/share/snapcam/captures/` as a `.jpg` pair plus a `.json` record.

## Requirements

- Linux (tested on Kali)
- `python3`, `curl`
- `cloudflared` — installed automatically by `install.sh`

HTTPS is required for the camera and location prompts, which is why the tunnel
is mandatory rather than optional.

## Usage

Run `snapcam`, copy the printed link, send it. Press `1` for a fresh tunnel,
`2` to list captures, `3` to dump the last one.

Links are shortened to `is.gd/arxelliot-xxxx` so they read as a personal
shortlink rather than a random tunnel host. The raw URL is always printed
underneath.

## Notes

- Free `trycloudflare.com` hosts are random and die with the process. A branded
  subdomain needs a Cloudflare account and a named tunnel.
- `captures/` is gitignored — it holds victim photos and coordinates.
- Denied permissions degrade gracefully: no GPS means no coordinates, no camera
  means no frames, the rest still posts.

## License

MIT

---

Created by **Arx Elliot**
