const jwt = require('jsonwebtoken');
const { query } = require('../db/pool');
const { formatUser } = require('../utils/formatters');

const auth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'sharebite_secret');
    const userId = decoded.userId || decoded.id;

    const { rows } = await query('SELECT * FROM users WHERE id = $1 LIMIT 1', [userId]);
    const user = rows[0];
    if (!user || !user.is_active) {
      return res.status(401).json({ success: false, message: 'User not found or inactive' });
    }

    req.userId = user.id;
    req.user = formatUser(user, { includeEmail: true });
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: 'Invalid token' });
    }
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    next(err);
  }
};

module.exports = auth;
