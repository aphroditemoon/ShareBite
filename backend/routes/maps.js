const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { query } = require('../db/pool');
const { formatListing } = require('../utils/formatters');

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

function distanceExpression(latParam = 1, lngParam = 2) {
  return `(6371000 * acos(least(1, greatest(-1,
    cos(radians($${latParam})) * cos(radians(l.lat)) * cos(radians(l.lng) - radians($${lngParam})) +
    sin(radians($${latParam})) * sin(radians(l.lat))
  ))))`;
}

router.get('/nearby', auth, async (req, res) => {
  try {
    const { lat, lng, radius = 15000 } = req.query;
    if (!lat || !lng) return res.status(400).json({ success: false, message: 'lat/lng required' });

    const distanceExpr = distanceExpression(1, 2);
    const { rows } = await query(
      `SELECT l.*, ${distanceExpr} AS distance, ${ownerSelect}
       FROM listings l
       JOIN users u ON u.id = l.owner_id
       WHERE l.is_available = TRUE AND ${distanceExpr} <= $3
       ORDER BY distance ASC
       LIMIT 100`,
      [parseFloat(lat), parseFloat(lng), parseInt(radius, 10) || 15000],
    );

    res.json({ success: true, data: { listings: rows.map(formatListing) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/geocode', auth, async (req, res) => {
  try {
    const { lat, lng } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ success: false, message: 'lat/lng required' });
    }

    const url = new URL('https://nominatim.openstreetmap.org/reverse');
    url.searchParams.set('format', 'jsonv2');
    url.searchParams.set('lat', lat);
    url.searchParams.set('lon', lng);
    url.searchParams.set('accept-language', 'id');

    const response = await fetch(url, {
      headers: { 'User-Agent': 'ShareBite/1.0 contact:dev@sharebite.local' },
    });

    if (response.ok) {
      const data = await response.json();
      if (data && data.display_name) {
        return res.json({
          success: true,
          data: { address: data.display_name, components: data.address || {} },
        });
      }
    }

    res.json({ success: true, data: { address: `${lat}, ${lng}`, components: {} } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
