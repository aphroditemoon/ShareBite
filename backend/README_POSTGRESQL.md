# ShareBite Backend - Express.js + PostgreSQL

Backend ini sudah dikonversi dari MongoDB/Mongoose ke PostgreSQL menggunakan package `pg`.

## Struktur utama

- `server.js` menjalankan Express API.
- `db/pool.js` berisi koneksi PostgreSQL.
- `db/schema.sql` berisi schema tabel PostgreSQL.
- `db/migrate.js` menjalankan schema otomatis.
- `seedDemo.js` membuat akun dan listing demo.
- `routes/*` sudah memakai query SQL PostgreSQL.

## Menjalankan dengan Docker Compose

Jalankan dari folder `GrandeButera`:

```bash
docker compose up --build
```

API berjalan di:

```text
http://localhost:3000
```

Cek koneksi:

```bash
curl http://localhost:3000/health
```

Akun demo:

```text
Email: demo@sharebite.app
Password: password123
```

## Menjalankan manual tanpa Docker

1. Buat database PostgreSQL:

```sql
CREATE DATABASE sharebite;
CREATE USER sharebite WITH PASSWORD 'sharebite';
GRANT ALL PRIVILEGES ON DATABASE sharebite TO sharebite;
```

2. Masuk folder backend dan install dependency:

```bash
npm install
cp .env.example .env
npm run migrate
npm run seed
npm run dev
```

## Catatan Flutter

Flutter tetap memakai endpoint:

```dart
static const String baseUrl = 'http://10.0.2.2:3000/api';
```

Untuk emulator Android, `10.0.2.2` mengarah ke localhost komputer. Untuk HP fisik, ganti ke IP LAN komputer, misalnya:

```dart
static const String baseUrl = 'http://192.168.1.10:3000/api';
```

PostgreSQL tidak ditanam langsung di APK. Arsitektur yang benar adalah Flutter APK → Express.js API → PostgreSQL.
