const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { query } = require('../db/pool');
const auth = require('../middleware/auth');
const { formatUser, formatListing, parseArrayInput } = require('../utils/formatters');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../uploads/avatars');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    cb(null, `avatar_${req.userId}${path.extname(file.originalname)}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 2 * 1024 * 1024 } });

const ownerSelect = `
  u.id AS owner_id,
  u.name AS owner_name,
  u.avatar AS owner_avatar,
  u.bio AS owner_bio,
  u.total_shared AS owner_total_shared,
  u.total_received AS owner_total_received,
  u.mealsaved AS owner_mealsaved,
  u.rating AS owner_rating,
  u.rating_count AS owner_rating_count
`;

router.get('/profile', auth, async (req, res) => {
  res.json({ success: true, data: { user: req.user } });
});

router.put('/profile', auth, upload.single('avatar'), async (req, res) => {
  try {
    const updates = [];
    const values = [];
    const set = (column, value) => {
      updates.push(`${column} = $${values.length + 1}`);
      values.push(value);
    };

    if (req.body.name) set('name', req.body.name);
    if (req.body.bio !== undefined) set('bio', req.body.bio);
    if (req.body.phone !== undefined) set('phone', req.body.phone || null);
    if (req.body.dietaryPreferences !== undefined) set('dietary_preferences', parseArrayInput(req.body.dietaryPreferences));
    if (req.body.favoriteCategories !== undefined) set('favorite_categories', parseArrayInput(req.body.favoriteCategories));
    if (req.file) set('avatar', `/uploads/avatars/${req.file.filename}`);
    if (req.body.lat !== undefined && req.body.lng !== undefined) {
      set('lat', parseFloat(req.body.lat));
      set('lng', parseFloat(req.body.lng));
      set('address', req.body.address || '');
    }

    if (updates.length === 0) {
      return res.json({ success: true, data: { user: req.user } });
    }

    updates.push('updated_at = NOW()');
    values.push(req.userId);
    const { rows } = await query(`UPDATE users SET ${updates.join(', ')} WHERE id = $${values.length} RETURNING *`, values);
    res.json({ success: true, data: { user: formatUser(rows[0], { includeEmail: true }) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.put('/location', auth, async (req, res) => {
  try {
    const { lat, lng, address } = req.body;
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'lat/lng required' });
    }

    await query(
      'UPDATE users SET lat = $1, lng = $2, address = $3, updated_at = NOW() WHERE id = $4',
      [parseFloat(lat), parseFloat(lng), address || '', req.userId],
    );
    res.json({ success: true, message: 'Location updated' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { rows } = await query('SELECT * FROM users WHERE id = $1 AND is_active = TRUE LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({ success: true, data: { user: formatUser(rows[0], { includeEmail: false }) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/:id/listings', async (req, res) => {
  try {
    const { rows } = await query(
      `SELECT l.*, NULL AS distance, ${ownerSelect}
       FROM listings l
       JOIN users u ON u.id = l.owner_id
       WHERE l.owner_id = $1 AND l.is_available = TRUE
       ORDER BY l.created_at DESC`,
      [req.params.id],
    );
    res.json({ success: true, data: { listings: rows.map(formatListing) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
