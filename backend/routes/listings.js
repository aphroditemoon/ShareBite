
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const { query, getClient } = require('../db/pool');
const auth = require('../middleware/auth');
const {
  formatListing,
  parseArrayInput,
} = require('../utils/formatters');

const allowedImageExtensions = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.heic',
  '.heif',
]);

const allowedImageMimeTypes = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'image/heif',
]);

function getImageExtension(file) {
  const originalExtension = path
    .extname(file.originalname || '')
    .toLowerCase();

  if (allowedImageExtensions.has(originalExtension)) {
    return originalExtension;
  }

  const mimeType = (file.mimetype || '').toLowerCase();

  const mimeExtensions = {
    'image/jpeg': '.jpg',
    'image/jpg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'image/gif': '.gif',
    'image/heic': '.heic',
    'image/heif': '.heif',
  };

  return mimeExtensions[mimeType] || '.jpg';
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const directory = path.join(
      __dirname,
      '../uploads/listings',
    );

    if (!fs.existsSync(directory)) {
      fs.mkdirSync(directory, {
        recursive: true,
      });
    }

    cb(null, directory);
  },

  filename: (req, file, cb) => {
    const extension = getImageExtension(file);

    const uniqueName = [
      'listing',
      Date.now(),
      Math.random().toString(36).slice(2, 10),
    ].join('_');

    cb(null, `${uniqueName}${extension}`);
  },
});

const upload = multer({
  storage,

  limits: {
    fileSize: 5 * 1024 * 1024,
    files: 5,
  },

  fileFilter: (req, file, cb) => {
    const mimeType = (file.mimetype || '')
      .trim()
      .toLowerCase();

    const extension = path
      .extname(file.originalname || '')
      .trim()
      .toLowerCase();

    const hasValidMime =
      allowedImageMimeTypes.has(mimeType);

    const hasValidExtension =
      allowedImageExtensions.has(extension);

    const isGenericMime =
      mimeType === '' ||
      mimeType === 'application/octet-stream';

    /*
     * File diterima apabila:
     * 1. MIME type adalah gambar yang didukung; atau
     * 2. Android mengirim application/octet-stream,
     *    tetapi nama file memiliki ekstensi gambar valid.
     */
    if (
      hasValidMime ||
      (isGenericMime && hasValidExtension)
    ) {
      return cb(null, true);
    }

    const error = new Error(
      `Only image files are allowed. Received: ${
        mimeType || 'unknown'
      }${extension ? ` (${extension})` : ''}`,
    );

    error.statusCode = 400;

    return cb(error);
  },
});

function uploadListingImages(req, res, next) {
  upload.array('images', 5)(req, res, (error) => {
    if (!error) {
      return next();
    }

    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
          success: false,
          message:
            'Image size is too large. Maximum size is 5 MB per image.',
        });
      }

      if (error.code === 'LIMIT_FILE_COUNT') {
        return res.status(400).json({
          success: false,
          message: 'Maximum 5 images are allowed.',
        });
      }

      if (error.code === 'LIMIT_UNEXPECTED_FILE') {
        return res.status(400).json({
          success: false,
          message:
            'Invalid image field. The expected field name is images.',
        });
      }

      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    return res.status(error.statusCode || 400).json({
      success: false,
      message: error.message || 'Image upload failed',
    });
  });
}

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

function baseListingSelect(distanceExpr = 'NULL') {
  return `
    SELECT
      l.*,
      ${distanceExpr} AS distance,
      ${ownerSelect}
    FROM listings l
    JOIN users u ON u.id = l.owner_id
  `;
}

function appendListingFilters(
  parts,
  values,
  {
    category,
    search,
    ownerId,
    isAvailable = true,
  },
) {
  if (isAvailable !== undefined) {
    parts.push(
      `l.is_available = $${values.length + 1}`,
    );

    values.push(isAvailable);
  }

  if (category && category !== 'all') {
    parts.push(
      `l.category = $${values.length + 1}`,
    );

    values.push(category);
  }

  if (ownerId) {
    parts.push(
      `l.owner_id = $${values.length + 1}`,
    );

    values.push(ownerId);
  }

  if (search) {
    const parameter = `%${search}%`;

    parts.push(`
      (
        l.title ILIKE $${values.length + 1}
        OR l.description ILIKE $${values.length + 1}
        OR array_to_string(l.tags, ' ')
          ILIKE $${values.length + 1}
      )
    `);

    values.push(parameter);
  }
}

function distanceExpression(
  latParam = 1,
  lngParam = 2,
) {
  return `
    (
      6371000 * acos(
        least(
          1,
          greatest(
            -1,
            cos(radians($${latParam}))
            * cos(radians(l.lat))
            * cos(
                radians(l.lng)
                - radians($${lngParam})
              )
            + sin(radians($${latParam}))
            * sin(radians(l.lat))
          )
        )
      )
    )
  `;
}

async function getListingWithOwner(id) {
  const { rows } = await query(
    `
      ${baseListingSelect()}
      WHERE l.id = $1
      LIMIT 1
    `,
    [id],
  );

  return rows[0]
    ? formatListing(rows[0])
    : null;
}

router.get('/', async (req, res) => {
  try {
    const {
      lat,
      lng,
      radius = 10000,
      category,
      search,
      page = 1,
      limit = 20,
      sort = 'distance',
    } = req.query;

    const pageNumber = Math.max(
      parseInt(page, 10) || 1,
      1,
    );

    const limitNumber = Math.min(
      Math.max(parseInt(limit, 10) || 20, 1),
      100,
    );

    const offset =
      (pageNumber - 1) * limitNumber;

    const hasLocation =
      lat !== undefined &&
      lng !== undefined &&
      lat !== '' &&
      lng !== '';

    const values = [];
    const whereParts = [];

    let distanceExpr = 'NULL';

    if (hasLocation) {
      values.push(
        parseFloat(lat),
        parseFloat(lng),
        parseInt(radius, 10) || 10000,
      );

      distanceExpr = distanceExpression(1, 2);

      whereParts.push(
        `${distanceExpr} <= $3`,
      );
    }

    appendListingFilters(
      whereParts,
      values,
      {
        category,
        search,
        isAvailable: true,
      },
    );

    const where = whereParts.length
      ? `WHERE ${whereParts.join(' AND ')}`
      : '';

    const orderBy =
      hasLocation && sort === 'distance'
        ? 'distance ASC'
        : 'l.created_at DESC';

    const sql = `
      ${baseListingSelect(distanceExpr)}
      ${where}
      ORDER BY ${orderBy}
      OFFSET $${values.length + 1}
      LIMIT $${values.length + 2}
    `;

    const listingValues = [
      ...values,
      offset,
      limitNumber,
    ];

    const { rows } = await query(
      sql,
      listingValues,
    );

    const countSql = `
      SELECT COUNT(*)::int AS total
      FROM listings l
      ${where}
    `;

    const countResult = await query(
      countSql,
      values,
    );

    const total =
      countResult.rows[0]?.total || 0;

    return res.json({
      success: true,
      data: {
        listings: rows.map(formatListing),
        pagination: {
          page: pageNumber,
          limit: limitNumber,
          total,
          pages: Math.ceil(
            total / limitNumber,
          ),
        },
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const listing =
      await getListingWithOwner(
        req.params.id,
      );

    if (!listing) {
      return res.status(404).json({
        success: false,
        message: 'Listing not found',
      });
    }

    await query(
      `
        UPDATE listings
        SET
          view_count = view_count + 1,
          updated_at = NOW()
        WHERE id = $1
      `,
      [req.params.id],
    );

    listing.viewCount += 1;

    return res.json({
      success: true,
      data: {
        listing,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
});

router.post(
  '/',
  auth,
  uploadListingImages,
  async (req, res) => {
    const client = await getClient();

    try {
      const {
        title,
        description,
        category,
        quantity,
        price,
        lat,
        lng,
        address,
        neighborhood,
        expiresAt,
        foodType,
        unit,
      } = req.body;

      if (!title || !category) {
        return res.status(400).json({
          success: false,
          message:
            'Title and category are required',
        });
      }

      if (
        lat === undefined ||
        lng === undefined ||
        lat === '' ||
        lng === ''
      ) {
        return res.status(400).json({
          success: false,
          message: 'Location required',
        });
      }

      const parsedLatitude =
        parseFloat(lat);

      const parsedLongitude =
        parseFloat(lng);

      if (
        !Number.isFinite(parsedLatitude) ||
        !Number.isFinite(parsedLongitude)
      ) {
        return res.status(400).json({
          success: false,
          message:
            'Latitude and longitude must be valid numbers',
        });
      }

      const images = Array.isArray(req.files)
        ? req.files.map(
            (file) =>
              `/uploads/listings/${file.filename}`,
          )
        : [];

      const tags = parseArrayInput(
        req.body.tags,
      );

      const allergens = parseArrayInput(
        req.body.allergens,
      );

      const dietaryInfo = parseArrayInput(
        req.body.dietaryInfo,
      );

      await client.query('BEGIN');

      const inserted = await client.query(
        `
          INSERT INTO listings (
            title,
            description,
            category,
            food_type,
            tags,
            images,
            quantity,
            unit,
            expires_at,
            price,
            owner_id,
            lng,
            lat,
            address,
            neighborhood,
            allergens,
            dietary_info
          )
          VALUES (
            $1, $2, $3, $4, $5, $6,
            $7, $8, $9, $10, $11,
            $12, $13, $14, $15,
            $16, $17
          )
          RETURNING *
        `,
        [
          title,
          description || '',
          category,
          foodType || null,
          tags,
          images,
          parseInt(quantity, 10) || 1,
          unit || 'item',
          expiresAt || null,
          parseFloat(price) || 0,
          req.userId,
          parsedLongitude,
          parsedLatitude,
          address || '',
          neighborhood || '',
          allergens,
          dietaryInfo,
        ],
      );

      await client.query(
        `
          UPDATE users
          SET
            total_shared = total_shared + 1,
            updated_at = NOW()
          WHERE id = $1
        `,
        [req.userId],
      );

      await client.query('COMMIT');

      const listing =
        await getListingWithOwner(
          inserted.rows[0].id,
        );

      return res.status(201).json({
        success: true,
        message: 'Listing created',
        data: {
          listing,
        },
      });
    } catch (error) {
      await client
        .query('ROLLBACK')
        .catch(() => {});

      return res.status(500).json({
        success: false,
        message: error.message,
      });
    } finally {
      client.release();
    }
  },
);

router.put(
  '/:id',
  auth,
  uploadListingImages,
  async (req, res) => {
    try {
      const found = await query(
        `
          SELECT *
          FROM listings
          WHERE id = $1
          LIMIT 1
        `,
        [req.params.id],
      );

      const listing = found.rows[0];

      if (!listing) {
        return res.status(404).json({
          success: false,
          message: 'Listing not found',
        });
      }

      if (
        String(listing.owner_id) !==
        String(req.userId)
      ) {
        return res.status(403).json({
          success: false,
          message: 'Not authorized',
        });
      }

      const updates = [];
      const values = [];

      const set = (column, value) => {
        updates.push(
          `${column} = $${values.length + 1}`,
        );

        values.push(value);
      };

      const allowedTextFields = {
        title: 'title',
        description: 'description',
        category: 'category',
        foodType: 'food_type',
        unit: 'unit',
        address: 'address',
        neighborhood: 'neighborhood',
      };

      Object.entries(
        allowedTextFields,
      ).forEach(([bodyKey, column]) => {
        if (
          req.body[bodyKey] !== undefined
        ) {
          set(column, req.body[bodyKey]);
        }
      });

      if (
        req.body.quantity !== undefined
      ) {
        set(
          'quantity',
          parseInt(
            req.body.quantity,
            10,
          ) || 1,
        );
      }

      if (req.body.price !== undefined) {
        set(
          'price',
          parseFloat(req.body.price) || 0,
        );
      }

      if (
        req.body.expiresAt !== undefined
      ) {
        set(
          'expires_at',
          req.body.expiresAt || null,
        );
      }

      if (
        req.body.isAvailable !== undefined
      ) {
        set(
          'is_available',
          req.body.isAvailable === true ||
            req.body.isAvailable === 'true',
        );
      }

      if (req.body.tags !== undefined) {
        set(
          'tags',
          parseArrayInput(req.body.tags),
        );
      }

      if (
        req.body.allergens !== undefined
      ) {
        set(
          'allergens',
          parseArrayInput(
            req.body.allergens,
          ),
        );
      }

      if (
        req.body.dietaryInfo !== undefined
      ) {
        set(
          'dietary_info',
          parseArrayInput(
            req.body.dietaryInfo,
          ),
        );
      }

      if (
        req.body.lat !== undefined &&
        req.body.lng !== undefined
      ) {
        const parsedLatitude =
          parseFloat(req.body.lat);

        const parsedLongitude =
          parseFloat(req.body.lng);

        if (
          !Number.isFinite(
            parsedLatitude,
          ) ||
          !Number.isFinite(
            parsedLongitude,
          )
        ) {
          return res.status(400).json({
            success: false,
            message:
              'Latitude and longitude must be valid numbers',
          });
        }

        set('lat', parsedLatitude);
        set('lng', parsedLongitude);
      }

      if (
        Array.isArray(req.files) &&
        req.files.length > 0
      ) {
        set(
          'images',
          req.files.map(
            (file) =>
              `/uploads/listings/${file.filename}`,
          ),
        );
      }

      if (updates.length === 0) {
        const unchangedListing =
          await getListingWithOwner(
            req.params.id,
          );

        return res.json({
          success: true,
          data: {
            listing: unchangedListing,
          },
        });
      }

      updates.push(
        'updated_at = NOW()',
      );

      values.push(req.params.id);

      await query(
        `
          UPDATE listings
          SET ${updates.join(', ')}
          WHERE id = $${values.length}
        `,
        values,
      );

      const updatedListing =
        await getListingWithOwner(
          req.params.id,
        );

      return res.json({
        success: true,
        data: {
          listing: updatedListing,
        },
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  },
);

router.delete(
  '/:id',
  auth,
  async (req, res) => {
    try {
      const found = await query(
        `
          SELECT id, owner_id
          FROM listings
          WHERE id = $1
          LIMIT 1
        `,
        [req.params.id],
      );

      const listing = found.rows[0];

      if (!listing) {
        return res.status(404).json({
          success: false,
          message: 'Listing not found',
        });
      }

      if (
        String(listing.owner_id) !==
        String(req.userId)
      ) {
        return res.status(403).json({
          success: false,
          message: 'Not authorized',
        });
      }

      await query(
        `
          DELETE FROM listings
          WHERE id = $1
        `,
        [req.params.id],
      );

      return res.json({
        success: true,
        message: 'Listing deleted',
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  },
);

module.exports = router;

