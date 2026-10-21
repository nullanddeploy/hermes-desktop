# Hermes Desktop

A full Ubuntu desktop (XFCE + VNC) with the **Hermes agent running inside it**
and the `computer_use` toolset enabled — so Hermes can see the screen and
drive its own computer: click, type, open apps, use the browser.

## How it works

- TigerVNC serves the desktop on display `:1`; noVNC exposes it in the
  browser on port **6080** (`/vnc.html`).
- Hermes runs as a Telegram gateway in the same container, with
  `platform_toolsets.telegram = [hermes-telegram, computer_use]`.
- The driver behind `computer_use` is **cua-driver**; it acts on the local
  display only, which is why Hermes and the desktop share one container.
- Default model: `nvidia/nemotron-3.5-super-vl:free` on OpenRouter
  (free, and it can see screenshots — required for computer use).

## Deploy on Railway

1. **New Project → Deploy from GitHub repo** → pick this repo.
2. Add variables (service → Variables):

   | Variable | Value |
   | --- | --- |
   | `TELEGRAM_BOT_TOKEN` | Token from @BotFather |
   | `RIVER_API_KEY` | Your River key (paid) — used when present |
   | `OPENROUTER_API_KEY` | Your OpenRouter key (free fallback) |
   | `VNC_PASSWORD` | Password for the desktop (default: `hermes`) |
   | `TELEGRAM_ALLOWED_USERS` | (optional) Your numeric Telegram ID |

   Provider priority: if `RIVER_API_KEY` is set, Hermes defaults to River's
   Nemotron VL model; otherwise it uses the free OpenRouter vision model.

3. **Settings → Networking → Generate Domain**, target port **6080**.
4. Open `https://<your-domain>/vnc.html` to see the desktop.
5. Message your bot on Telegram, e.g. *"take a screenshot and tell me
   what you see"* or *"open Chrome and go to google.com"*.

## Notes

- Everything lives in the container filesystem — a redeploy resets the
  desktop. API keys and tokens are re-injected from variables on boot.
- First boot can take a while (desktop + gateway startup).
