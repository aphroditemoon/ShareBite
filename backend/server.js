require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const { pool } = require('./db/pool');
const runMigrations = require('./db/migrate');
const seedDemoData = require('./seedDemo');

const app = express();

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
});
app.use('/api', limiter);

app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/listings', require('./routes/listings'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/ml', require('./routes/ml'));
app.use('/api/maps', require('./routes/maps'));
app.use('/api/requests', require('./routes/requests'));

app.get('/health', async (req, res, next) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'OK',
      database: 'PostgreSQL connected',
      timestamp: new Date().toISOString(),
      service: 'ShareBite API',
    });
  } catch (err) {
    next(err);
  }
});

app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

app.use((err, req, res, next) => {
  console.error(err.stack || err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await pool.query('SELECT 1');
    console.log('✅ PostgreSQL connected');

    if (process.env.DB_AUTO_MIGRATE !== 'false') {
      await runMigrations();
      console.log('✅ PostgreSQL schema ready');
    }

    if (process.env.SEED_DEMO !== 'false') {
      await seedDemoData();
    }

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 ShareBite Express API running on port ${PORT}`);
    });
  } catch (err) {
    console.error('❌ PostgreSQL startup error:', err);
    process.exit(1);
  }
}

if (require.main === module) {
  start();
}

module.exports = app;
