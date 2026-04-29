# Phantom Note

Browser-based guitar practice, music theory, and songwriting toolkit. Everything runs client-side in a single `index.html` file — no backend required for the app itself. The server exists purely to serve the static files and prepare for production hosting on a Raspberry Pi.

## Features (10 Tabs)

| Tab | Name | What It Does |
|-----|------|-------------|
| 1 | **Scales & Practice** | Fretboard visualization with scale/mode overlays, paired scales, practice mode with mic input |
| 2 | **Harmonize** | Harmonized scale view across the full neck, color-coded by chord degree |
| 3 | **Chords** | Chord library organized by scale degree with voicing diagrams and audio playback |
| 4 | **Finder** | Reverse chord finder — click frets to place notes, get chord identification. Supports custom tunings (Drop D, Open G, etc.) |
| 5 | **Lyrics** | Lyrics & chords scroller with metronome, song save/load, auto-scroll |
| 6 | **Analyzer** | Song analyzer that detects key and chords from pasted text |
| 7 | **Audio to MIDI** | Record audio via microphone, detect pitches, edit on piano roll, export as .mid |
| 8 | **Chord Detect** | Real-time chord detection from audio file upload |
| 9 | **Sample Chopper** | MPC-style audio sample slicing with keyboard/MIDI pad mapping |
| 10 | **Progressions** | Chord progression generator with playback, organized by genre/mood |

## Architecture

```
Browser                    Raspberry Pi
┌──────────────┐          ┌──────────────────────────────────┐
│  index.html  │  ←HTTP─  │  nginx (:80) → Express (:3000)  │
│  (all JS/CSS │          │        ↕                         │
│   inline)    │          │      pm2 (process manager)       │
└──────────────┘          └──────────────────────────────────┘
```

- **Frontend:** Single `index.html` (~8,000 lines) with all CSS and JS inline. Uses vanilla JavaScript, Tone.js (CDN), Web Audio API, and Web MIDI API. All audio processing happens in the browser.
- **Server:** Node.js + Express serves static files from `public/`. Includes helmet (security headers), compression (gzip), morgan (logging), and CORS.
- **Reverse Proxy:** nginx sits in front of Express on the Pi, handling port 80/443 and forwarding to localhost:3000.
- **Process Manager:** pm2 keeps the Node server running and auto-restarts on crash or reboot.

## Project Structure

```
Phantom_Note/
├── public/
│   ├── index.html          # The app (all client-side code)
│   └── ads.txt             # Google AdSense placeholder
├── server/
│   ├── server.js           # Express server
│   └── config.js           # Server configuration
├── scripts/
│   ├── setup-pi.sh         # One-time Raspberry Pi setup
│   └── deploy.sh           # Deploy from Mac to Pi
├── .env.example            # Environment variable template
├── .gitignore
├── package.json
└── README.md
```

## Local Development

### Prerequisites

- Node.js 18+ (check with `node --version`)

### Setup

```bash
# Install dependencies
npm install

# Start the dev server (auto-restarts on file changes)
npm run dev

# Or start without auto-restart
npm start
```

The app will be available at **http://localhost:3000**.

The health check endpoint is at **http://localhost:3000/health**.

### Note on index.html

The root `index.html` is the working copy. The `public/index.html` is what the server serves. After making edits to `index.html`, copy it to `public/`:

```bash
cp index.html public/index.html
```

This will be automated in a future build step.

## Raspberry Pi Deployment

### First-Time Setup (run on the Pi)

1. SSH into your Pi:
   ```bash
   ssh pi@raspberrypi.local
   ```

2. Copy the setup script to the Pi and run it:
   ```bash
   # From your Mac:
   scp scripts/setup-pi.sh pi@raspberrypi.local:~/setup-pi.sh

   # On the Pi:
   chmod +x ~/setup-pi.sh
   ~/setup-pi.sh
   ```

   This installs Node.js, pm2, nginx, and configures the firewall.

### Deploying Updates (run from your Mac)

1. Create a `.env` file from the template:
   ```bash
   cp .env.example .env
   # Edit .env with your Pi's IP/hostname
   ```

2. Deploy:
   ```bash
   npm run deploy
   # or: bash scripts/deploy.sh 192.168.1.100
   ```

   This rsyncs the project to the Pi, installs deps, and restarts pm2.

3. Access the site at **http://your-pi-ip** (port 80 via nginx).

### Useful Pi Commands

```bash
# Check server status
ssh pi@raspberrypi.local 'pm2 status'

# View server logs
ssh pi@raspberrypi.local 'pm2 logs phantom-note'

# Restart the server
ssh pi@raspberrypi.local 'pm2 restart phantom-note'

# Check nginx status
ssh pi@raspberrypi.local 'sudo systemctl status nginx'
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Port the Express server listens on |
| `NODE_ENV` | `development` | Set to `production` on the Pi |
| `PI_HOST` | `raspberrypi.local` | Pi hostname/IP (used by deploy script) |
| `PI_USER` | `pi` | SSH username for the Pi |
| `PI_APP_DIR` | `~/phantom-note` | Where the app lives on the Pi |

## Google AdSense Roadmap

### Prerequisites (before applying)

- [ ] **Domain name** — AdSense requires a real domain (not an IP or `.local`). Buy one from Namecheap, Google Domains, etc.
- [ ] **SSL/HTTPS** — Required by AdSense. Use Let's Encrypt + certbot (free). The nginx config has a commented-out SSL section ready to go.
- [ ] **Privacy Policy page** — Google requires one. Add a `/privacy` route or a `privacy.html` page explaining what data the site collects (basically none, since everything is client-side).
- [ ] **About page** — Helps with AdSense approval. Brief page explaining what Phantom Note is.
- [ ] **Sufficient content** — The site needs enough real content to be reviewed. Phantom Note's 10 feature tabs should be plenty.
- [ ] **Site must be live** — The site needs to be publicly accessible for Google to review it.
- [ ] **Original content** — All code and content must be original (it is).

### Where Ad Units Would Go

When ready to add AdSense code to `index.html`:

1. **Header banner** — Between the navigation bar and tab content. A responsive leaderboard (728x90 on desktop, auto-sizing on mobile).
2. **Between tab sections** — If tabs are ever split into separate pages, an ad between content sections.
3. **Footer area** — Below the main content, above the footer text.
4. **Sidebar** — On desktop, if the layout ever gets a sidebar, a vertical ad unit (300x250 or 160x600).

The actual AdSense script tag goes in the `<head>` of `index.html`, and individual ad units are `<ins>` elements placed where you want them.

### Steps After Prerequisites Are Met

1. Sign up at [adsense.google.com](https://adsense.google.com)
2. Add the AdSense verification snippet to `index.html`'s `<head>`
3. Wait for site review (can take days to weeks)
4. Once approved, update `public/ads.txt` with your publisher ID
5. Create ad units in the AdSense dashboard and place the code in `index.html`

## Future Plans

- **Modularization** — Break `index.html` into separate JS/CSS modules with a build step (Vite or esbuild)
- **User accounts** — Optional login to sync saved songs, tunings, and preferences across devices
- **PWA support** — Service worker for offline use, add-to-homescreen on mobile
- **Mobile optimization** — Responsive layouts for all tabs (some are desktop-first currently)
- **MIDI file import** — Load .mid files into the Audio to MIDI tab for editing
- **Sharing** — Share chord progressions, song charts via URL
