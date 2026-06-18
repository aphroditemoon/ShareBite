const bcrypt = require('bcryptjs');
const { query, getClient } = require('./db/pool');

async function seedDemoData() {
  const demoEmail = 'demo@sharebite.app';
  const existing = await query('SELECT * FROM users WHERE email = $1 LIMIT 1', [demoEmail]);
  let demoUser = existing.rows[0];

  if (!demoUser) {
    const hashedPassword = await bcrypt.hash('password123', 12);
    const inserted = await query(
      `INSERT INTO users (
        name, email, password, phone, bio, is_verified, badges,
        lng, lat, address, total_shared, total_received, mealsaved, rating, rating_count
      ) VALUES (
        $1, $2, $3, $4, $5, TRUE, $6,
        $7, $8, $9, $10, $11, $12, $13, $14
      ) RETURNING *`,
      [
        'Demo ShareBite',
        demoEmail,
        hashedPassword,
        '081234567890',
        'Akun demo untuk mencoba aplikasi ShareBite',
        ['Demo User'],
        106.8456,
        -6.2088,
        'Jakarta, Indonesia',
        3,
        2,
        8,
        4.8,
        12,
      ],
    );
    demoUser = inserted.rows[0];
    console.log('✅ Demo user created: demo@sharebite.app / password123');
  }

  const count = await query('SELECT COUNT(*)::int AS total FROM listings WHERE owner_id = $1', [demoUser.id]);
  if (count.rows[0].total > 0) return;

  const client = await getClient();
  try {
    await client.query('BEGIN');

    const demoListings = [
      {
        title: 'Nasi Box Ayam Goreng',
        description: 'Sisa acara kantor, masih fresh dan layak makan. Bisa diambil sore ini.',
        category: 'free_food',
        foodType: 'meal',
        tags: ['nasi', 'ayam', 'halal'],
        images: [],
        quantity: 5,
        unit: 'box',
        price: 0,
        expiresAt: new Date(Date.now() + 8 * 60 * 60 * 1000),
        lng: 106.8456,
        lat: -6.2088,
        address: 'Menteng, Jakarta Pusat',
        neighborhood: 'Menteng',
        dietaryInfo: ['Halal'],
        allergens: [],
      },
      {
        title: 'Roti dan Pastry Mix',
        description: 'Roti bakery hari ini. Cocok untuk sarapan besok pagi.',
        category: 'free_food',
        foodType: 'bakery',
        tags: ['roti', 'pastry', 'bakery'],
        images: [],
        quantity: 8,
        unit: 'pcs',
        price: 0,
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        lng: 106.8175,
        lat: -6.1754,
        address: 'Tanah Abang, Jakarta',
        neighborhood: 'Tanah Abang',
        dietaryInfo: ['Vegetarian'],
        allergens: ['Gluten', 'Susu'],
      },
      {
        title: 'Buku Catatan Bekas Layak Pakai',
        description: 'Masih banyak halaman kosong. Gratis untuk yang membutuhkan.',
        category: 'free_nonfood',
        foodType: null,
        tags: ['buku', 'alat tulis'],
        images: [],
        quantity: 4,
        unit: 'buku',
        price: 0,
        expiresAt: null,
        lng: 106.7920,
        lat: -6.2383,
        address: 'Kebayoran Lama, Jakarta',
        neighborhood: 'Kebayoran Lama',
        dietaryInfo: [],
        allergens: [],
      },
    ];

    for (const item of demoListings) {
      await client.query(
        `INSERT INTO listings (
          title, description, category, food_type, tags, images, quantity, unit,
          expires_at, price, owner_id, lng, lat, address, neighborhood, dietary_info, allergens
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8,
          $9, $10, $11, $12, $13, $14, $15, $16, $17
        )`,
        [
          item.title,
          item.description,
          item.category,
          item.foodType,
          item.tags,
          item.images,
          item.quantity,
          item.unit,
          item.expiresAt,
          item.price,
          demoUser.id,
          item.lng,
          item.lat,
          item.address,
          item.neighborhood,
          item.dietaryInfo,
          item.allergens,
        ],
      );
    }

    await client.query('COMMIT');
    console.log('✅ Demo listings created');
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

module.exports = seedDemoData;
