// =====================================================================
// Server Configuration
// =====================================================================
// Loads environment variables from .env file (if present) and exports
// a single config object used throughout the server.

require('dotenv').config();

const config = {
  // Server port — defaults to 3000 if not set in .env
  port: parseInt(process.env.PORT, 10) || 3000,

  // Environment — 'development' or 'production'
  env: process.env.NODE_ENV || 'development',

  // Log directory for access logs
  logDir: process.env.LOG_DIR || 'logs',

  // Whether we're running in production
  isProduction: process.env.NODE_ENV === 'production',
};

module.exports = config;
