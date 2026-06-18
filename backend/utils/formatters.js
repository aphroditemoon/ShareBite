function numeric(value, fallback = 0) {
  if (value === null || value === undefined || value === '') return fallback;
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function int(value, fallback = 0) {
  return Math.trunc(numeric(value, fallback));
}

function array(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.filter((item) => item !== null && item !== undefined).map(String);
  return [];
}

function parseArrayInput(value) {
  if (value === undefined || value === null || value === '') return [];
  if (Array.isArray(value)) return value.map((item) => String(item).trim()).filter(Boolean);
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return [];
    try {
      const decoded = JSON.parse(trimmed);
      if (Array.isArray(decoded)) return decoded.map((item) => String(item).trim()).filter(Boolean);
    } catch (_) {}
    return trimmed.split(',').map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

function formatDate(value) {
  if (!value) return null;
  try {
    return new Date(value).toISOString();
  } catch (_) {
    return value;
  }
}

function formatStats(row, prefix = '') {
  return {
    totalShared: int(row[`${prefix}total_shared`]),
    totalReceived: int(row[`${prefix}total_received`]),
    mealsaved: int(row[`${prefix}mealsaved`]),
    rating: numeric(row[`${prefix}rating`]),
    ratingCount: int(row[`${prefix}rating_count`]),
  };
}

function formatUser(row, options = {}) {
  if (!row) return null;
  const includeEmail = options.includeEmail !== false;
  const user = {
    _id: row.id,
    id: row.id,
    name: row.name || '',
    avatar: row.avatar || null,
    phone: row.phone || null,
    bio: row.bio || '',
    location: {
      type: 'Point',
      coordinates: [numeric(row.lng), numeric(row.lat)],
      address: row.address || '',
    },
    badges: array(row.badges),
    stats: formatStats(row),
    isVerified: Boolean(row.is_verified),
    isActive: row.is_active !== false,
    lastSeen: formatDate(row.last_seen),
    dietaryPreferences: array(row.dietary_preferences),
    favoriteCategories: array(row.favorite_categories),
    createdAt: formatDate(row.created_at),
    updatedAt: formatDate(row.updated_at),
  };
  if (includeEmail) user.email = row.email || '';
  return user;
}

function formatOwnerFromListingRow(row) {
  if (!row || !row.owner_id) return null;
  return {
    _id: row.owner_id,
    id: row.owner_id,
    name: row.owner_name || '',
    avatar: row.owner_avatar || null,
    bio: row.owner_bio || '',
    stats: {
      totalShared: int(row.owner_total_shared),
      totalReceived: int(row.owner_total_received),
      mealsaved: int(row.owner_mealsaved),
      rating: numeric(row.owner_rating),
      ratingCount: int(row.owner_rating_count),
    },
  };
}

function formatListing(row) {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    title: row.title || '',
    description: row.description || '',
    category: row.category || 'free_food',
    foodType: row.food_type || null,
    tags: array(row.tags),
    images: array(row.images),
    quantity: int(row.quantity, 1),
    unit: row.unit || 'item',
    expiresAt: formatDate(row.expires_at),
    price: numeric(row.price),
    isAvailable: row.is_available !== false,
    owner: row.owner || formatOwnerFromListingRow(row),
    location: {
      type: 'Point',
      coordinates: [numeric(row.lng), numeric(row.lat)],
      address: row.address || '',
      neighborhood: row.neighborhood || '',
    },
    requests: [],
    viewCount: int(row.view_count),
    allergens: array(row.allergens),
    dietaryInfo: array(row.dietary_info),
    mlEmbedding: row.ml_embedding || null,
    distance: row.distance === undefined || row.distance === null ? null : numeric(row.distance),
    createdAt: formatDate(row.created_at),
    updatedAt: formatDate(row.updated_at),
  };
}

function formatMessage(row) {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    conversation: row.conversation_id,
    sender: row.sender || (row.sender_id ? {
      _id: row.sender_id,
      id: row.sender_id,
      name: row.sender_name || '',
      avatar: row.sender_avatar || null,
    } : null),
    content: row.content || '',
    type: row.type || 'text',
    isRead: Boolean(row.is_read),
    readAt: formatDate(row.read_at),
    createdAt: formatDate(row.created_at),
    updatedAt: formatDate(row.updated_at),
  };
}

function formatRequest(row) {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    listing: row.listing || row.listing_id,
    requester: row.requester || row.requester_id,
    owner: row.owner || row.owner_id,
    status: row.status || 'pending',
    message: row.message || '',
    quantity: int(row.quantity, 1),
    rating: row.rating,
    review: row.review,
    createdAt: formatDate(row.created_at),
    updatedAt: formatDate(row.updated_at),
  };
}

module.exports = {
  numeric,
  int,
  array,
  parseArrayInput,
  formatDate,
  formatUser,
  formatListing,
  formatMessage,
  formatRequest,
};
