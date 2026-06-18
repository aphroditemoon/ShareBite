const express = require('express');
const router = express.Router();
const { query, getClient } = require('../db/pool');
const auth = require('../middleware/auth');
const { formatRequest } = require('../utils/formatters');

function listingMini(row) {
  if (!row.listing_id) return null;
  return {
    _id: row.listing_id,
    id: row.listing_id,
    title: row.listing_title || '',
    images: row.listing_images || [],
    category: row.listing_category || '',
  };
}

function userMini(row, prefix) {
  const id = row[`${prefix}_id`];
  if (!id) return null;
  return {
    _id: id,
    id,
    name: row[`${prefix}_name`] || '',
    avatar: row[`${prefix}_avatar`] || null,
    stats: row[`${prefix}_total_shared`] === undefined ? undefined : {
      totalShared: Number(row[`${prefix}_total_shared`] || 0),
      totalReceived: Number(row[`${prefix}_total_received`] || 0),
      mealsaved: Number(row[`${prefix}_mealsaved`] || 0),
      rating: Number(row[`${prefix}_rating`] || 0),
      ratingCount: Number(row[`${prefix}_rating_count`] || 0),
    },
  };
}

async function hydrateRequest(id) {
  const { rows } = await query(
    `SELECT r.*,
      l.id AS listing_id, l.title AS listing_title, l.images AS listing_images, l.category AS listing_category,
      requester.id AS requester_id, requester.name AS requester_name, requester.avatar AS requester_avatar,
      requester.total_shared AS requester_total_shared, requester.total_received AS requester_total_received,
      requester.mealsaved AS requester_mealsaved, requester.rating AS requester_rating, requester.rating_count AS requester_rating_count,
      owner.id AS owner_id, owner.name AS owner_name, owner.avatar AS owner_avatar,
      owner.total_shared AS owner_total_shared, owner.total_received AS owner_total_received,
      owner.mealsaved AS owner_mealsaved, owner.rating AS owner_rating, owner.rating_count AS owner_rating_count
     FROM requests r
     JOIN listings l ON l.id = r.listing_id
     JOIN users requester ON requester.id = r.requester_id
     JOIN users owner ON owner.id = r.owner_id
     WHERE r.id = $1
     LIMIT 1`,
    [id],
  );
  const row = rows[0];
  if (!row) return null;
  return formatRequest({
    ...row,
    listing: listingMini(row),
    requester: userMini(row, 'requester'),
    owner: userMini(row, 'owner'),
  });
}

router.post('/', auth, async (req, res) => {
  try {
    const { listingId, message, quantity } = req.body;
    if (!listingId) return res.status(400).json({ success: false, message: 'listingId required' });

    const listingRes = await query('SELECT id, owner_id FROM listings WHERE id = $1 AND is_available = TRUE LIMIT 1', [listingId]);
    const listing = listingRes.rows[0];
    if (!listing) return res.status(404).json({ success: false, message: 'Listing not found' });
    if (String(listing.owner_id) === String(req.userId)) {
      return res.status(400).json({ success: false, message: 'Cannot request your own listing' });
    }

    const existing = await query(
      `SELECT id FROM requests
       WHERE listing_id = $1 AND requester_id = $2 AND status IN ('pending', 'accepted')
       LIMIT 1`,
      [listingId, req.userId],
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'Already requested' });
    }

    const inserted = await query(
      `INSERT INTO requests (listing_id, requester_id, owner_id, message, quantity)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [listingId, req.userId, listing.owner_id, message || '', parseInt(quantity, 10) || 1],
    );

    const request = await hydrateRequest(inserted.rows[0].id);
    res.status(201).json({ success: true, data: { request } });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ success: false, message: 'Already requested' });
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/my', auth, async (req, res) => {
  try {
    const { rows } = await query(
      `SELECT r.*,
        l.id AS listing_id, l.title AS listing_title, l.images AS listing_images, l.category AS listing_category,
        owner.id AS owner_id, owner.name AS owner_name, owner.avatar AS owner_avatar
       FROM requests r
       JOIN listings l ON l.id = r.listing_id
       JOIN users owner ON owner.id = r.owner_id
       WHERE r.requester_id = $1
       ORDER BY r.created_at DESC`,
      [req.userId],
    );

    const requests = rows.map((row) => formatRequest({
      ...row,
      listing: listingMini(row),
      owner: userMini(row, 'owner'),
    }));
    res.json({ success: true, data: { requests } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/incoming', auth, async (req, res) => {
  try {
    const { rows } = await query(
      `SELECT r.*,
        l.id AS listing_id, l.title AS listing_title, l.images AS listing_images, l.category AS listing_category,
        requester.id AS requester_id, requester.name AS requester_name, requester.avatar AS requester_avatar,
        requester.total_shared AS requester_total_shared, requester.total_received AS requester_total_received,
        requester.mealsaved AS requester_mealsaved, requester.rating AS requester_rating, requester.rating_count AS requester_rating_count
       FROM requests r
       JOIN listings l ON l.id = r.listing_id
       JOIN users requester ON requester.id = r.requester_id
       WHERE r.owner_id = $1 AND r.status = 'pending'
       ORDER BY r.created_at DESC`,
      [req.userId],
    );

    const requests = rows.map((row) => formatRequest({
      ...row,
      listing: listingMini(row),
      requester: userMini(row, 'requester'),
    }));
    res.json({ success: true, data: { requests } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.patch('/:id/status', auth, async (req, res) => {
  const client = await getClient();
  try {
    const { status } = req.body;
    const allowed = ['pending', 'accepted', 'rejected', 'completed', 'cancelled'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    await client.query('BEGIN');
    const found = await client.query('SELECT * FROM requests WHERE id = $1 LIMIT 1', [req.params.id]);
    const request = found.rows[0];
    if (!request) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Request not found' });
    }
    if (String(request.owner_id) !== String(req.userId)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    await client.query('UPDATE requests SET status = $1, updated_at = NOW() WHERE id = $2', [status, req.params.id]);

    if (status === 'completed') {
      await client.query(
        'UPDATE users SET total_received = total_received + 1, updated_at = NOW() WHERE id = $1',
        [request.requester_id],
      );
      await client.query(
        'UPDATE users SET mealsaved = mealsaved + 1, updated_at = NOW() WHERE id = $1',
        [request.owner_id],
      );
    }

    await client.query('COMMIT');
    const updated = await hydrateRequest(req.params.id);
    res.json({ success: true, data: { request: updated } });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    res.status(500).json({ success: false, message: err.message });
  } finally {
    client.release();
  }
});

module.exports = router;
