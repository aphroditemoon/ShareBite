CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  password TEXT NOT NULL,
  avatar TEXT,
  phone VARCHAR(40),
  bio TEXT DEFAULT '',
  lng DOUBLE PRECISION DEFAULT 0,
  lat DOUBLE PRECISION DEFAULT 0,
  address TEXT DEFAULT '',
  badges TEXT[] DEFAULT ARRAY[]::TEXT[],
  total_shared INTEGER NOT NULL DEFAULT 0,
  total_received INTEGER NOT NULL DEFAULT 0,
  mealsaved INTEGER NOT NULL DEFAULT 0,
  rating NUMERIC(3,2) NOT NULL DEFAULT 0,
  rating_count INTEGER NOT NULL DEFAULT 0,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fcm_token TEXT,
  dietary_preferences TEXT[] DEFAULT ARRAY[]::TEXT[],
  favorite_categories TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users (is_active);

CREATE TABLE IF NOT EXISTS listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(180) NOT NULL,
  description TEXT DEFAULT '',
  category VARCHAR(40) NOT NULL CHECK (category IN ('free_food', 'free_nonfood', 'for_sale', 'borrow', 'wanted')),
  food_type VARCHAR(80),
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  images TEXT[] DEFAULT ARRAY[]::TEXT[],
  quantity INTEGER NOT NULL DEFAULT 1,
  unit VARCHAR(40) NOT NULL DEFAULT 'item',
  expires_at TIMESTAMPTZ,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lng DOUBLE PRECISION NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  address TEXT DEFAULT '',
  neighborhood TEXT DEFAULT '',
  view_count INTEGER NOT NULL DEFAULT 0,
  allergens TEXT[] DEFAULT ARRAY[]::TEXT[],
  dietary_info TEXT[] DEFAULT ARRAY[]::TEXT[],
  ml_embedding JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_listings_owner ON listings (owner_id);
CREATE INDEX IF NOT EXISTS idx_listings_category_available ON listings (category, is_available);
CREATE INDEX IF NOT EXISTS idx_listings_available_created ON listings (is_available, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_tags ON listings USING GIN (tags);

CREATE TABLE IF NOT EXISTS requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'completed', 'cancelled')),
  message TEXT DEFAULT '',
  quantity INTEGER NOT NULL DEFAULT 1,
  rating INTEGER,
  review TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_requests_requester ON requests (requester_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_requests_owner_status ON requests (owner_id, status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_requests_one_active
  ON requests (listing_id, requester_id)
  WHERE status IN ('pending', 'accepted');

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID REFERENCES listings(id) ON DELETE SET NULL,
  last_message_id UUID,
  last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conversation_participants_user ON conversation_participants (user_id);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'system')),
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON messages (conversation_id, created_at ASC);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'conversations_last_message_fk'
  ) THEN
    ALTER TABLE conversations
      ADD CONSTRAINT conversations_last_message_fk
      FOREIGN KEY (last_message_id) REFERENCES messages(id) ON DELETE SET NULL
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;
