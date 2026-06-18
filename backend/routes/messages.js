const express = require('express');
const router = express.Router();
const { query, getClient } = require('../db/pool');
const auth = require('../middleware/auth');
const { formatMessage } = require('../utils/formatters');

function formatParticipant(row) {
  return {
    _id: row.id,
    id: row.id,
    name: row.name || '',
    avatar: row.avatar || null,
    lastSeen: row.last_seen ? new Date(row.last_seen).toISOString() : null,
  };
}

async function loadConversationDetails(conversation) {
  const participantsRes = await query(
    `SELECT u.id, u.name, u.avatar, u.last_seen
     FROM conversation_participants cp
     JOIN users u ON u.id = cp.user_id
     WHERE cp.conversation_id = $1
     ORDER BY u.name ASC`,
    [conversation.id],
  );

  let listing = null;
  if (conversation.listing_id) {
    const listingRes = await query(
      'SELECT id, title, images, category FROM listings WHERE id = $1 LIMIT 1',
      [conversation.listing_id],
    );
    if (listingRes.rows[0]) {
      const row = listingRes.rows[0];
      listing = { _id: row.id, id: row.id, title: row.title, images: row.images || [], category: row.category };
    }
  }

  let lastMessage = null;
  if (conversation.last_message_id) {
    const messageRes = await query(
      `SELECT m.*, u.id AS sender_id, u.name AS sender_name, u.avatar AS sender_avatar
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.id = $1
       LIMIT 1`,
      [conversation.last_message_id],
    );
    if (messageRes.rows[0]) lastMessage = formatMessage(messageRes.rows[0]);
  }

  return {
    _id: conversation.id,
    id: conversation.id,
    participants: participantsRes.rows.map(formatParticipant),
    listing,
    lastMessage,
    lastMessageAt: conversation.last_message_at ? new Date(conversation.last_message_at).toISOString() : null,
    unreadCount: {},
    createdAt: conversation.created_at ? new Date(conversation.created_at).toISOString() : null,
    updatedAt: conversation.updated_at ? new Date(conversation.updated_at).toISOString() : null,
  };
}

router.get('/conversations', auth, async (req, res) => {
  try {
    const { rows } = await query(
      `SELECT c.*
       FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
       WHERE cp.user_id = $1
       ORDER BY c.last_message_at DESC`,
      [req.userId],
    );

    const conversations = [];
    for (const row of rows) {
      conversations.push(await loadConversationDetails(row));
    }

    res.json({ success: true, data: { conversations } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/conversations/:id', auth, async (req, res) => {
  try {
    const member = await query(
      'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2 LIMIT 1',
      [req.params.id, req.userId],
    );
    if (member.rows.length === 0) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    const { rows } = await query(
      `SELECT m.*, u.id AS sender_id, u.name AS sender_name, u.avatar AS sender_avatar
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.conversation_id = $1
       ORDER BY m.created_at ASC`,
      [req.params.id],
    );

    await query(
      `UPDATE messages
       SET is_read = TRUE, read_at = NOW(), updated_at = NOW()
       WHERE conversation_id = $1 AND sender_id <> $2 AND is_read = FALSE`,
      [req.params.id, req.userId],
    );

    res.json({ success: true, data: { messages: rows.map(formatMessage) } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/', auth, async (req, res) => {
  const client = await getClient();
  try {
    const { recipientId, listingId, content } = req.body;
    if (!recipientId || !content) {
      return res.status(400).json({ success: false, message: 'recipientId and content are required' });
    }
    if (String(recipientId) === String(req.userId)) {
      return res.status(400).json({ success: false, message: 'Cannot message yourself' });
    }

    await client.query('BEGIN');

    const recipient = await client.query('SELECT id FROM users WHERE id = $1 AND is_active = TRUE LIMIT 1', [recipientId]);
    if (recipient.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, message: 'Recipient not found' });
    }

    let conversationId;
    const existing = await client.query(
      `SELECT c.id
       FROM conversations c
       JOIN conversation_participants p1 ON p1.conversation_id = c.id AND p1.user_id = $1
       JOIN conversation_participants p2 ON p2.conversation_id = c.id AND p2.user_id = $2
       WHERE (
         ($3::uuid IS NULL AND c.listing_id IS NULL)
         OR c.listing_id = $3::uuid
       )
       LIMIT 1`,
      [req.userId, recipientId, listingId || null],
    );

    if (existing.rows[0]) {
      conversationId = existing.rows[0].id;
    } else {
      const created = await client.query(
        'INSERT INTO conversations (listing_id) VALUES ($1) RETURNING id',
        [listingId || null],
      );
      conversationId = created.rows[0].id;
      await client.query(
        'INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1, $2), ($1, $3)',
        [conversationId, req.userId, recipientId],
      );
    }

    const inserted = await client.query(
      `INSERT INTO messages (conversation_id, sender_id, content)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [conversationId, req.userId, content],
    );

    await client.query(
      `UPDATE conversations
       SET last_message_id = $1, last_message_at = NOW(), updated_at = NOW()
       WHERE id = $2`,
      [inserted.rows[0].id, conversationId],
    );

    await client.query('COMMIT');

    const messageRes = await query(
      `SELECT m.*, u.id AS sender_id, u.name AS sender_name, u.avatar AS sender_avatar
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.id = $1
       LIMIT 1`,
      [inserted.rows[0].id],
    );

    res.status(201).json({
      success: true,
      data: { message: formatMessage(messageRes.rows[0]), conversationId },
    });
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    res.status(500).json({ success: false, message: err.message });
  } finally {
    client.release();
  }
});

module.exports = router;
