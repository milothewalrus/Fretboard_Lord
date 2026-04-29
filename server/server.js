// =====================================================================
// Phantom Note — Express Server
// =====================================================================
// Lightweight server that serves the static frontend and provides
// basic infrastructure (logging, security headers, compression).
// Designed to run behind nginx on a Raspberry Pi in production.

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const config = require('./config');

const app = express();

// =====================================================================
// Middleware
// =====================================================================

// Security headers via helmet
// We relax some defaults so the inline scripts/styles in index.html work.
// In production behind nginx, nginx handles some of this too.
app.use(helmet({
  contentSecurityPolicy: false,       // index.html uses inline scripts & styles
  crossOriginEmbedderPolicy: false,   // we load fonts/scripts from CDNs
}));

// CORS — allow all origins for now (can lock down to your domain later)
app.use(cors());

// Gzip compression for all responses
app.use(compression());

// =====================================================================
// Request Logging
// =====================================================================
// Log to stdout always; in production, also write to logs/access.log.

// Stdout logging (short format in dev, combined in prod)
app.use(morgan(config.isProduction ? 'combined' : 'dev'));

// File logging in production
if (config.isProduction) {
  const logDir = path.join(__dirname, '..', config.logDir);
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }
  const accessLogStream = fs.createWriteStream(
    path.join(logDir, 'access.log'),
    { flags: 'a' }  // append mode
  );
  app.use(morgan('combined', { stream: accessLogStream }));
}

// =====================================================================
// Routes
// =====================================================================

// Health check — useful for uptime monitoring and load balancers
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

// =====================================================================
// Static File Serving
// =====================================================================
// Serve everything in public/ with appropriate cache headers.

// HTML files: short cache (so users always get the latest version)
// Other assets: longer cache (CSS, JS, images, fonts)
app.use(express.static(path.join(__dirname, '..', 'public'), {
  etag: true,
  lastModified: true,
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
      // Don't cache HTML — always serve fresh
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else {
      // Cache other assets for 1 day (86400s); in production you might go longer
      res.setHeader('Cache-Control', 'public, max-age=86400');
    }
  },
}));

// Fallback: serve index.html for any unmatched route (SPA-style)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// =====================================================================
// Start Server
// =====================================================================

const server = app.listen(config.port, () => {
  console.log(`Phantom Note server running on port ${config.port} [${config.env}]`);
  console.log(`  Local:   http://localhost:${config.port}`);
});

// =====================================================================
// Graceful Shutdown
// =====================================================================
// When pm2 or the OS sends a stop signal, close connections cleanly
// before exiting. This prevents dropped requests during deploys.

function shutdown(signal) {
  console.log(`\n${signal} received — shutting down gracefully...`);
  server.close(() => {
    console.log('Server closed. Goodbye.');
    process.exit(0);
  });
  // Force exit after 10 seconds if connections won't close
  setTimeout(() => {
    console.error('Forcing shutdown after timeout.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
