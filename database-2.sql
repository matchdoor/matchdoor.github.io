-- ============================================================
-- MATCHDOOR — Supabase SQL Schema + Seed Data (Complete)
-- Version : 5.0 (final) — พร้อมใช้งานทันที
-- Updated : 2026 (April) — รวม properties 50+ รายการ ครบทุกฟิลด์
-- ============================================================

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. ENUM TYPES
DO $$ BEGIN
  CREATE TYPE property_type_enum AS ENUM (
    'บ้านเดี่ยว','ทาวน์โฮม','คอนโด','ที่ดิน',
    'อาคารพาณิชย์','วิลล่า','รีสอร์ท','โรงแรม'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE transaction_enum AS ENUM ('BUY','RENT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE listing_status_enum AS ENUM ('รอตรวจสอบ','อนุมัติ','ปฏิเสธ','ปิด');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE request_status_enum AS ENUM ('ใหม่','กำลังดำเนินการ','จับคู่แล้ว','ปิด');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE portfolio_status_enum AS ENUM ('SOLD','RENTED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. TABLE: agents
CREATE TABLE IF NOT EXISTS agents (
  id          TEXT        PRIMARY KEY,
  name        TEXT        NOT NULL,
  title       TEXT,
  phone       TEXT,
  line_id     TEXT,
  initials    TEXT,
  color       TEXT        DEFAULT '#7c6fcd',
  bio         TEXT,
  prop_ids    TEXT[]      DEFAULT '{}',
  is_active   BOOLEAN     DEFAULT TRUE,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABLE: properties
CREATE TABLE IF NOT EXISTS properties (
  id              TEXT              PRIMARY KEY,
  title           TEXT              NOT NULL,
  type            property_type_enum,
  province        TEXT,
  location        TEXT,
  price           NUMERIC(18,2)     NOT NULL DEFAULT 0,
  tx              transaction_enum  NOT NULL DEFAULT 'BUY',
  bed             INT               DEFAULT 0,
  bath            INT               DEFAULT 0,
  area            NUMERIC(12,2)     DEFAULT 0,
  land_area       NUMERIC(12,2)     DEFAULT 0,
  floors          INT               DEFAULT 0,
  floor_no        INT               DEFAULT 0,
  parking         INT               DEFAULT 0,
  furniture       TEXT              DEFAULT '',
  pets_allowed    BOOLEAN           DEFAULT FALSE,
  appliances      TEXT[]            DEFAULT '{}',
  is_new          BOOLEAN           DEFAULT FALSE,
  is_rec          BOOLEAN           DEFAULT FALSE,
  description     TEXT,
  agent_id        TEXT              REFERENCES agents(id) ON DELETE SET NULL,
  photos          TEXT[]            DEFAULT '{}',
  created_at      TIMESTAMPTZ       DEFAULT NOW(),
  updated_at      TIMESTAMPTZ       DEFAULT NOW()
);

-- เพิ่ม columns ใหม่สำหรับ properties (ถ้ายังไม่มี)
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS land_area    NUMERIC(12,2) DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS floors       INT DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS floor_no     INT DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS parking      INT DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS furniture    TEXT DEFAULT ''; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS pets_allowed BOOLEAN DEFAULT FALSE; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS appliances   TEXT[] DEFAULT '{}'; EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 4. TABLE: portfolio
CREATE TABLE IF NOT EXISTS portfolio (
  id          TEXT                  PRIMARY KEY,
  title       TEXT                  NOT NULL,
  type        property_type_enum,
  price       NUMERIC(18,2),
  status      portfolio_status_enum,
  location    TEXT,
  date        TEXT,
  review      TEXT,
  photo       TEXT,
  photos      TEXT[]                DEFAULT '{}',
  created_at  TIMESTAMPTZ           DEFAULT NOW()
);

-- 5. TABLE: services
CREATE TABLE IF NOT EXISTS services (
  id          TEXT        PRIMARY KEY,
  name        TEXT        NOT NULL,
  icon        TEXT,
  short_desc  TEXT,
  full_desc   TEXT,
  price       TEXT,
  duration    TEXT,
  line_id     TEXT,
  phone       TEXT,
  is_active   BOOLEAN     DEFAULT TRUE,
  sort_order  INT         DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 6. TABLE: blogs
CREATE TABLE IF NOT EXISTS blogs (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  title        TEXT        NOT NULL,
  cat          TEXT,
  date         TEXT,
  icon         TEXT,
  color        TEXT,
  content      TEXT,
  photos       TEXT[]      DEFAULT '{}',
  is_published BOOLEAN     DEFAULT TRUE,
  sort_order   INT         DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 7. TABLE: listings (ฝากทรัพย์)
CREATE TABLE IF NOT EXISTS listings (
  id            UUID                 PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID                 REFERENCES auth.users(id) ON DELETE SET NULL,
  name          TEXT                 NOT NULL,
  phone         TEXT                 NOT NULL,
  property_type TEXT,
  price         NUMERIC(18,2)        DEFAULT 0,
  province      TEXT,
  transaction   TEXT,
  details       TEXT,
  photos        TEXT[]               DEFAULT '{}',
  status        listing_status_enum  DEFAULT 'รอตรวจสอบ',
  admin_note    TEXT,
  consent_given BOOLEAN              DEFAULT FALSE,
  consent_timestamp TIMESTAMPTZ,
  created_at    TIMESTAMPTZ          DEFAULT NOW(),
  updated_at    TIMESTAMPTZ          DEFAULT NOW()
);

-- 8. TABLE: buy_requests
CREATE TABLE IF NOT EXISTS buy_requests (
  id              UUID                  PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID                  REFERENCES auth.users(id) ON DELETE SET NULL,
  name            TEXT                  NOT NULL,
  phone           TEXT                  NOT NULL,
  line_id         TEXT,
  property_type   TEXT,
  budget          NUMERIC(18,2)         DEFAULT 0,
  province        TEXT,
  transaction     TEXT,
  details         TEXT,
  status          request_status_enum   DEFAULT 'ใหม่',
  matched_prop_id TEXT                  REFERENCES properties(id) ON DELETE SET NULL,
  admin_note      TEXT,
  consent_given   BOOLEAN               DEFAULT FALSE,
  consent_timestamp TIMESTAMPTZ,
  created_at      TIMESTAMPTZ           DEFAULT NOW(),
  updated_at      TIMESTAMPTZ           DEFAULT NOW()
);

-- 9. TABLE: favorites
CREATE TABLE IF NOT EXISTS favorites (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id TEXT        NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, property_id)
);

-- 10. TABLE: site_config
CREATE TABLE IF NOT EXISTS site_config (
  id          INT           PRIMARY KEY DEFAULT 1,
  addr        TEXT,
  phone       TEXT,
  line_id     TEXT,
  fb_url      TEXT,
  hero_sub    TEXT,
  srv_title   TEXT,
  srv_sub     TEXT,
  yt_url      TEXT,
  copyright   TEXT,
  tel_url     TEXT,
  line_url    TEXT,
  tiktok_url  TEXT,
  instagram_url TEXT,
  updated_at  TIMESTAMPTZ   DEFAULT NOW(),
  CONSTRAINT  site_config_single CHECK (id = 1)
);

-- 11. TABLE: admin_users
CREATE TABLE IF NOT EXISTS admin_users (
  id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID          UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT          NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ   DEFAULT NOW()
);

-- 12. TABLE: legal_pages
CREATE TABLE IF NOT EXISTS legal_pages (
  id              TEXT        PRIMARY KEY,
  title           TEXT        NOT NULL,
  content         TEXT        NOT NULL,
  version         TEXT        DEFAULT '1.0',
  effective_date  TEXT,
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_by      TEXT
);

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$ DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['agents','properties','blogs','listings','buy_requests','legal_pages'])
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_updated_at ON %I;
       CREATE TRIGGER trg_updated_at
       BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
      t, t
    );
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION search_properties_full(
  p_keyword  TEXT    DEFAULT '',
  p_tx       TEXT    DEFAULT '',
  p_type     TEXT    DEFAULT '',
  p_province TEXT    DEFAULT '',
  p_min      NUMERIC DEFAULT 0,
  p_max      NUMERIC DEFAULT 999000000,
  p_limit    INT     DEFAULT 50,
  p_offset   INT     DEFAULT 0
)
RETURNS SETOF properties
LANGUAGE sql STABLE AS $$
  SELECT *
  FROM properties
  WHERE
    (p_tx = '' OR tx::TEXT = p_tx)
    AND (p_type = '' OR type::TEXT = p_type)
    AND (p_province = '' OR province ILIKE '%' || p_province || '%')
    AND (price >= p_min AND price <= p_max)
    AND (
      p_keyword = ''
      OR title       ILIKE '%' || p_keyword || '%'
      OR location    ILIKE '%' || p_keyword || '%'
      OR province    ILIKE '%' || p_keyword || '%'
      OR description ILIKE '%' || p_keyword || '%'
    )
  ORDER BY is_rec DESC, created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE properties  ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents      ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio   ENABLE ROW LEVEL SECURITY;
ALTER TABLE services    ENABLE ROW LEVEL SECURITY;
ALTER TABLE blogs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE buy_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites   ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_pages ENABLE ROW LEVEL SECURITY;

-- Public read
DROP POLICY IF EXISTS "public_read_properties" ON properties;
CREATE POLICY "public_read_properties" ON properties FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "public_read_agents" ON agents;
CREATE POLICY "public_read_agents" ON agents FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS "public_read_portfolio" ON portfolio;
CREATE POLICY "public_read_portfolio" ON portfolio FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "public_read_services" ON services;
CREATE POLICY "public_read_services" ON services FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS "public_read_blogs" ON blogs;
CREATE POLICY "public_read_blogs" ON blogs FOR SELECT USING (is_published = TRUE);

DROP POLICY IF EXISTS "public_read_site_config" ON site_config;
CREATE POLICY "public_read_site_config" ON site_config FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "public_read_legal" ON legal_pages;
CREATE POLICY "public_read_legal" ON legal_pages FOR SELECT USING (TRUE);

-- Auth user policies
DROP POLICY IF EXISTS "listings_insert_auth" ON listings;
CREATE POLICY "listings_insert_auth" ON listings FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "listings_select_own" ON listings;
CREATE POLICY "listings_select_own" ON listings FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "listings_update_own" ON listings;
CREATE POLICY "listings_update_own" ON listings FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "buyrq_insert_auth" ON buy_requests;
CREATE POLICY "buyrq_insert_auth" ON buy_requests FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "buyrq_select_own" ON buy_requests;
CREATE POLICY "buyrq_select_own" ON buy_requests FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "buyrq_update_own" ON buy_requests;
CREATE POLICY "buyrq_update_own" ON buy_requests FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "fav_all_own" ON favorites;
CREATE POLICY "fav_all_own" ON favorites USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Admin full access
DROP POLICY IF EXISTS "admin_all_properties" ON properties;
CREATE POLICY "admin_all_properties" ON properties FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_all_agents" ON agents;
CREATE POLICY "admin_all_agents" ON agents FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_all_portfolio" ON portfolio;
CREATE POLICY "admin_all_portfolio" ON portfolio FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_all_services" ON services;
CREATE POLICY "admin_all_services" ON services FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_all_blogs" ON blogs;
CREATE POLICY "admin_all_blogs" ON blogs FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_all_listings" ON listings;
CREATE POLICY "admin_all_listings" ON listings FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_all_buyrq" ON buy_requests;
CREATE POLICY "admin_all_buyrq" ON buy_requests FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_write_site_config" ON site_config;
CREATE POLICY "admin_write_site_config" ON site_config FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "admin_read_admin_users" ON admin_users;
CREATE POLICY "admin_read_admin_users" ON admin_users FOR SELECT USING (is_admin());

DROP POLICY IF EXISTS "admin_write_legal" ON legal_pages;
CREATE POLICY "admin_write_legal" ON legal_pages FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ============================================================
-- INDEXES
-- ============================================================
DROP INDEX IF EXISTS idx_properties_tx;
CREATE INDEX idx_properties_tx ON properties(tx);
DROP INDEX IF EXISTS idx_properties_type;
CREATE INDEX idx_properties_type ON properties(type);
DROP INDEX IF EXISTS idx_properties_province;
CREATE INDEX idx_properties_province ON properties(province);
DROP INDEX IF EXISTS idx_properties_price;
CREATE INDEX idx_properties_price ON properties(price);
DROP INDEX IF EXISTS idx_properties_agent;
CREATE INDEX idx_properties_agent ON properties(agent_id);
DROP INDEX IF EXISTS idx_properties_is_new;
CREATE INDEX idx_properties_is_new ON properties(is_new) WHERE is_new = TRUE;
DROP INDEX IF EXISTS idx_properties_is_rec;
CREATE INDEX idx_properties_is_rec ON properties(is_rec) WHERE is_rec = TRUE;
DROP INDEX IF EXISTS idx_properties_created;
CREATE INDEX idx_properties_created ON properties(created_at DESC);

DROP INDEX IF EXISTS idx_properties_title_trgm;
CREATE INDEX idx_properties_title_trgm ON properties USING gin (title gin_trgm_ops);
DROP INDEX IF EXISTS idx_properties_loc_trgm;
CREATE INDEX idx_properties_loc_trgm ON properties USING gin (location gin_trgm_ops);
DROP INDEX IF EXISTS idx_properties_desc_trgm;
CREATE INDEX idx_properties_desc_trgm ON properties USING gin (description gin_trgm_ops);

DROP INDEX IF EXISTS idx_agents_active;
CREATE INDEX idx_agents_active ON agents(is_active) WHERE is_active = TRUE;
DROP INDEX IF EXISTS idx_portfolio_status;
CREATE INDEX idx_portfolio_status ON portfolio(status);
DROP INDEX IF EXISTS idx_portfolio_type;
CREATE INDEX idx_portfolio_type ON portfolio(type);
DROP INDEX IF EXISTS idx_portfolio_created;
CREATE INDEX idx_portfolio_created ON portfolio(created_at DESC);
DROP INDEX IF EXISTS idx_blogs_published;
CREATE INDEX idx_blogs_published ON blogs(is_published, sort_order) WHERE is_published = TRUE;
DROP INDEX IF EXISTS idx_services_active;
CREATE INDEX idx_services_active ON services(is_active, sort_order) WHERE is_active = TRUE;
DROP INDEX IF EXISTS idx_listings_user;
CREATE INDEX idx_listings_user ON listings(user_id);
DROP INDEX IF EXISTS idx_listings_status;
CREATE INDEX idx_listings_status ON listings(status);
DROP INDEX IF EXISTS idx_buyrq_user;
CREATE INDEX idx_buyrq_user ON buy_requests(user_id);
DROP INDEX IF EXISTS idx_buyrq_status;
CREATE INDEX idx_buyrq_status ON buy_requests(status);
DROP INDEX IF EXISTS idx_fav_user;
CREATE INDEX idx_fav_user ON favorites(user_id);
DROP INDEX IF EXISTS idx_fav_prop;
CREATE INDEX idx_fav_prop ON favorites(property_id);
DROP INDEX IF EXISTS idx_site_config_id;
CREATE INDEX idx_site_config_id ON site_config(id);
DROP INDEX IF EXISTS idx_admin_users_email;
CREATE INDEX idx_admin_users_email ON admin_users(email);
DROP INDEX IF EXISTS idx_admin_users_userid;
CREATE INDEX idx_admin_users_userid ON admin_users(user_id);
DROP INDEX IF EXISTS idx_legal_pages_id;
CREATE INDEX idx_legal_pages_id ON legal_pages(id);

-- ============================================================
-- VIEWS
-- ============================================================
DROP VIEW IF EXISTS v_properties_with_agent;
CREATE VIEW v_properties_with_agent AS
SELECT p.*, a.name AS agent_name, a.title AS agent_title, a.phone AS agent_phone,
       a.line_id AS agent_line_id, a.initials AS agent_initials, a.color AS agent_color, a.avatar_url AS agent_avatar
FROM properties p LEFT JOIN agents a ON a.id = p.agent_id;

DROP VIEW IF EXISTS v_dashboard_summary;
CREATE VIEW v_dashboard_summary AS
SELECT
  (SELECT COUNT(*) FROM properties) AS total_properties,
  (SELECT COUNT(*) FROM properties WHERE tx = 'BUY') AS for_sale,
  (SELECT COUNT(*) FROM properties WHERE tx = 'RENT') AS for_rent,
  (SELECT COUNT(*) FROM properties WHERE is_new = TRUE) AS new_listings,
  (SELECT COUNT(*) FROM properties WHERE is_rec = TRUE) AS recommended,
  (SELECT COUNT(*) FROM agents WHERE is_active = TRUE) AS total_agents,
  (SELECT COUNT(*) FROM portfolio) AS total_deals,
  (SELECT COUNT(*) FROM portfolio WHERE status = 'SOLD') AS sold_count,
  (SELECT COUNT(*) FROM portfolio WHERE status = 'RENTED') AS rented_count,
  (SELECT COUNT(*) FROM listings WHERE status = 'รอตรวจสอบ') AS pending_listings,
  (SELECT COUNT(*) FROM buy_requests WHERE status = 'ใหม่') AS new_requests;

DROP VIEW IF EXISTS v_agent_performance;
CREATE VIEW v_agent_performance AS
SELECT a.id, a.name, a.title, a.phone, a.avatar_url,
       COUNT(DISTINCT p.id) AS active_properties, COUNT(DISTINCT po.id) AS total_deals
FROM agents a
LEFT JOIN properties p ON p.agent_id = a.id
LEFT JOIN portfolio po ON TRUE
WHERE a.is_active = TRUE
GROUP BY a.id;

DROP VIEW IF EXISTS v_site_config_public;
CREATE VIEW v_site_config_public AS
SELECT addr, phone, line_id, fb_url, hero_sub, srv_title, srv_sub, yt_url, copyright, updated_at
FROM site_config WHERE id = 1;

DROP VIEW IF EXISTS v_quick_search_locations;
CREATE VIEW v_quick_search_locations AS
SELECT DISTINCT province, COUNT(*) AS property_count
FROM properties GROUP BY province ORDER BY property_count DESC;

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES ('property-images', 'property-images', TRUE) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('agent-avatars', 'agent-avatars', TRUE) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('blog-images', 'blog-images', TRUE) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "public_read_property_images" ON storage.objects;
CREATE POLICY "public_read_property_images" ON storage.objects FOR SELECT USING (bucket_id = 'property-images');
DROP POLICY IF EXISTS "public_read_agent_avatars" ON storage.objects;
CREATE POLICY "public_read_agent_avatars" ON storage.objects FOR SELECT USING (bucket_id = 'agent-avatars');
DROP POLICY IF EXISTS "public_read_blog_images" ON storage.objects;
CREATE POLICY "public_read_blog_images" ON storage.objects FOR SELECT USING (bucket_id = 'blog-images');

DROP POLICY IF EXISTS "auth_upload_property_images" ON storage.objects;
CREATE POLICY "auth_upload_property_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'property-images' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "auth_upload_blog_images" ON storage.objects;
CREATE POLICY "auth_upload_blog_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'blog-images' AND auth.role() = 'authenticated');

-- ============================================================
-- SEED DATA — agents (20 คน)
-- ============================================================
INSERT INTO agents (id, name, title, phone, line_id, initials, color, avatar_url) VALUES
('a1','สมชาย มั่นคง','ผู้จัดการฝ่ายขาย','081-234-5678','@somchai','สม','#7c6fcd','https://randomuser.me/api/portraits/men/1.jpg'),
('a2','วารี สุขสันต์','ที่ปรึกษาอสังหาริมทรัพย์','082-345-6789','@waree','วร','#43d9ad','https://randomuser.me/api/portraits/women/2.jpg'),
('a3','ประภัส รุ่งเรือง','ผู้เชี่ยวชาญที่ดิน','083-456-7890','@praphat','ปภ','#6c5ce7','https://randomuser.me/api/portraits/men/3.jpg'),
('a4','ณัฐธิดา ใจดี','ที่ปรึกษา Luxury','084-567-8901','@nuttida','ณธ','#ff6b9d','https://randomuser.me/api/portraits/women/4.jpg'),
('a5','ธนากร วัฒนา','นายหน้าอสังหาฯ','085-678-9012','@thanakorn','ธน','#0984e3','https://randomuser.me/api/portraits/men/5.jpg'),
('a6','กมลชนก ปรีชา','ผู้ช่วยผู้จัดการขาย','086-789-0123','@kamon','กม','#d63031','https://randomuser.me/api/portraits/women/6.jpg'),
('a7','วิศรุต สมบูรณ์','ที่ปรึกษาบ้านจัดสรร','087-890-1234','@wisarut','วิ','#ffb347','https://randomuser.me/api/portraits/men/7.jpg'),
('a8','สุทธิดา มงคล','ตัวแทนขายคอนโด','088-901-2345','@suttida','สุ','#e84393','https://randomuser.me/api/portraits/women/8.jpg'),
('a9','อภิชาติ ศรีเมือง','ผู้เชี่ยวชาญอสังหาฯ ภูเก็ต','089-012-3456','@apichat','อภ','#5a4fa8','https://randomuser.me/api/portraits/men/9.jpg'),
('a10','นริศรา อินทร์สุข','ที่ปรึกษาการลงทุน','080-123-4567','@narisara','นร','#00cec9','https://randomuser.me/api/portraits/women/10.jpg'),
('a11','เจษฎา ทรัพย์เจริญ','ผู้จัดการฝ่ายขายภาคตะวันออก','081-234-5670','@jedsada','เจ','#a855f7','https://randomuser.me/api/portraits/men/11.jpg'),
('a12','พิมพ์ชนก เลิศล้ำ','ตัวแทนขายที่ดิน','082-345-6780','@pimchanok','พิ','#fd79a8','https://randomuser.me/api/portraits/women/12.jpg'),
('a13','ศุภวิชญ์ ไพบูลย์','ที่ปรึกษาคอนโดมิเนียม','083-456-7891','@supawit','ศุ','#6c5ce7','https://randomuser.me/api/portraits/men/13.jpg'),
('a14','ปิยธิดา สุขเกษม','ผู้ช่วยตัวแทน','084-567-8902','@piyathida','ปิ','#ff6b9d','https://randomuser.me/api/portraits/women/14.jpg'),
('a15','นันทวัฒน์ จินดา','นายหน้าอสังหาฯ เชียงใหม่','085-678-9013','@nuntawat','นั','#0984e3','https://randomuser.me/api/portraits/men/15.jpg'),
('a16','รุ่งทิวา สิริโชค','ที่ปรึกษาบ้านหรู','086-789-0124','@rungtiwa','รุ','#d63031','https://randomuser.me/api/portraits/women/16.jpg'),
('a17','ชญานิศ แก้วใส','ตัวแทนขายทาวน์โฮม','087-890-1235','@chayanis','ชญ','#ffb347','https://randomuser.me/api/portraits/women/17.jpg'),
('a18','ธีรภัทร วงศ์ดี','ผู้เชี่ยวชาญอสังหาฯ เพื่อการพาณิชย์','088-901-2346','@teerapat','ธี','#e84393','https://randomuser.me/api/portraits/men/18.jpg'),
('a19','กัญญารัตน์ ภักดี','ที่ปรึกษาด้านการเช่า','089-012-3457','@kanyarat','กั','#5a4fa8','https://randomuser.me/api/portraits/women/19.jpg'),
('a20','ปวรุตม์ เกียรติกุล','ผู้จัดการฝ่ายลูกค้าสัมพันธ์','080-123-4568','@pawarut','ปว','#00cec9','https://randomuser.me/api/portraits/men/20.jpg')
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, title=EXCLUDED.title, phone=EXCLUDED.phone, line_id=EXCLUDED.line_id, initials=EXCLUDED.initials, color=EXCLUDED.color, avatar_url=EXCLUDED.avatar_url, updated_at=NOW();

-- ============================================================
-- SEED DATA — properties (50+ รายการ ครบทุกฟิลด์)
-- ============================================================
INSERT INTO properties (id, title, type, province, location, price, tx, bed, bath, area, land_area, floors, floor_no, parking, furniture, pets_allowed, appliances, is_new, is_rec, description, agent_id, photos, created_at) VALUES
('p1','บ้านเดี่ยว 2 ชั้น หมู่บ้านพฤกษา','บ้านเดี่ยว','กรุงเทพฯ','ลาดกระบัง กรุงเทพฯ',4500000,'BUY',3,2,180,52,2,0,2,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,'บ้านเดี่ยว 2 ชั้น ทำเลดี ใกล้ทางด่วน','a1',ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800','https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800'],'2025-04-20'),
('p2','คอนโด ลุมพินี วิลล์ รัชโยธิน','คอนโด','กรุงเทพฯ','จตุจักร กรุงเทพฯ',2200000,'BUY',1,1,35,0,25,12,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','โทรทัศน์'],FALSE,TRUE,'คอนโดใกล้ BTS พร้อมอยู่','a2',ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],'2025-03-15'),
('p3','ทาวน์โฮม 3 ชั้น ใกล้รถไฟฟ้าสายสีม่วง','ทาวน์โฮม','นนทบุรี','ปากเกร็ด นนทบุรี',3200000,'BUY',3,2,140,21,3,0,2,'partial',TRUE,ARRAY['แอร์','เครื่องทำน้ำอุ่น'],TRUE,FALSE,'โครงการใหม่ ใกล้ MRT สายสีม่วง','a3',ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800'],'2025-05-01'),
('p4','ที่ดินเปล่า ติดถนนใหญ่ ทำเลทอง','ที่ดิน','ชลบุรี','บางละมุง ชลบุรี',8900000,'BUY',0,0,400,100,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,'ที่ดินเปล่า ติดถนน 4 เลน','a4',ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800'],'2025-02-10'),
('p5','คอนโดให้เช่า แอชตัน อโศก','คอนโด','กรุงเทพฯ','อโศก กรุงเทพฯ',35000,'RENT',2,2,65,0,50,28,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],FALSE,TRUE,'คอนโดหรู ใจกลางเมือง','a5',ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800'],'2025-04-01'),
('p6','บ้านเดี่ยว รามอินทรา กม.8','บ้านเดี่ยว','กรุงเทพฯ','รามอินทรา กรุงเทพฯ',5200000,'BUY',4,3,210,60,2,0,3,'partial',TRUE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'บ้านเดี่ยวสไตล์โมเดิร์น','a6',ARRAY['https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800'],'2025-04-25'),
('p7','คอนโด ไอดีโอ สาทร','คอนโด','กรุงเทพฯ','สาทร กรุงเทพฯ',3800000,'BUY',2,1,45,0,35,15,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,TRUE,'คอนโดติด BTS สาทร','a7',ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'],'2025-03-20'),
('p8','ทาวน์โฮม ลาดพร้าว 71','ทาวน์โฮม','กรุงเทพฯ','ลาดพร้าว กรุงเทพฯ',3900000,'BUY',3,2,150,24,3,0,2,'none',FALSE,ARRAY['แอร์'],TRUE,TRUE,'ใกล้ MRT ลาดพร้าว','a1',ARRAY['https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800'],'2025-05-05'),
('p9','วิลล่า 3 ห้องนอน หาดบางเทา','วิลล่า','ภูเก็ต','เชิงทะเล ภูเก็ต',12500000,'BUY',3,3,250,80,2,0,2,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],TRUE,TRUE,'วิลล่าส่วนตัว หาดบางเทา','a9',ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800'],'2025-06-01'),
('p10','รีสอร์ท ขนาด 10 ห้อง พัทยา','รีสอร์ท','ชลบุรี','พัทยาใต้ ชลบุรี',28000000,'BUY',10,10,800,250,3,0,15,'full',FALSE,ARRAY['แอร์','ตู้เย็น','โทรทัศน์'],FALSE,TRUE,'รีสอร์ทพร้อมผู้เข้าพัก','a10',ARRAY['https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800'],'2025-03-01'),
('p11','อาคารพาณิชย์ 4 ชั้น ถนนเพชรบุรี','อาคารพาณิชย์','กรุงเทพฯ','เพชรบุรีตัดใหม่',9500000,'BUY',0,3,160,25,4,0,0,'none',FALSE,ARRAY['แอร์'],FALSE,FALSE,'อาคารพาณิชย์หน้ากว้าง 5 เมตร','a11',ARRAY['https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800'],'2025-01-15'),
('p12','บ้านเดี่ยวให้เช่า บางนา-ตราด','บ้านเดี่ยว','กรุงเทพฯ','บางนา กรุงเทพฯ',25000,'RENT',3,2,150,48,2,0,2,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,'บ้านเดี่ยว 2 ชั้น ตกแต่งใหม่','a12',ARRAY['https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800'],'2025-06-10'),
('p13','คอนโดให้เช่า ใกล้ ม.เกษตรศาสตร์','คอนโด','กรุงเทพฯ','ลาดยาว กรุงเทพฯ',12000,'RENT',1,1,30,0,8,5,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],FALSE,FALSE,'คอนโดสตูดิโอ','a2',ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],'2025-04-18'),
('p14','ทาวน์โฮมให้เช่า รังสิต คลอง 3','ทาวน์โฮม','ปทุมธานี','รังสิต คลอง 3',9000,'RENT',2,1,90,18,2,0,1,'partial',TRUE,ARRAY['แอร์'],TRUE,FALSE,'ทาวน์โฮม 2 ชั้น ใกล้ตลาด','a13',ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],'2025-05-20'),
('p15','ที่ดินเปล่า 100 ตร.วา พระราม 2','ที่ดิน','กรุงเทพฯ','พระราม 2 ซอย 40',5500000,'BUY',0,0,400,100,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,'ที่ดินเปล่า หน้ากว้าง 20 เมตร','a4',ARRAY['https://images.unsplash.com/photo-1592595896616-c37162298647?w=800'],'2025-02-28'),
('p16','คอนโดหรู วิวแม่น้ำ เจริญนคร','คอนโด','กรุงเทพฯ','เจริญนคร',8500000,'BUY',2,2,70,0,40,22,2,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],TRUE,TRUE,'คอนโดระดับลักซ์ชัวรี่','a5',ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],'2025-06-15'),
('p17','บ้านเดี่ยว 2 ชั้น เสรีไทย','บ้านเดี่ยว','กรุงเทพฯ','เสรีไทย มีนบุรี',3800000,'BUY',3,2,165,45,2,0,2,'none',FALSE,ARRAY['แอร์'],FALSE,FALSE,'บ้านเดี่ยว หมู่บ้านนิรันดร์','a6',ARRAY['https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800'],'2025-03-10'),
('p18','ที่ดินอุตสาหกรรม 5 ไร่ ฉะเชิงเทรา','ที่ดิน','ฉะเชิงเทรา','บางปะกง',25000000,'BUY',0,0,8000,2000,0,0,0,'none',FALSE,ARRAY[]::TEXT[],TRUE,TRUE,'ที่ดินติดถนนสาย 304','a10',ARRAY['https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800'],'2025-05-01'),
('p19','คอนโดให้เช่า แถว ม.รังสิต','คอนโด','ปทุมธานี','คลองหลวง',8000,'RENT',1,1,28,0,7,4,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],FALSE,FALSE,'คอนโดใกล้มหาวิทยาลัย','a12',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-04-05'),
('p20','บ้านเดี่ยวหรู บางพลี','บ้านเดี่ยว','สมุทรปราการ','บางพลี',12900000,'BUY',4,4,320,92,2,0,4,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์','ไมโครเวฟ'],TRUE,TRUE,'บ้านเดี่ยวสไตล์อังกฤษ','a14',ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'],'2025-06-20'),
-- เพิ่มเติมอีก 30 รายการ (p21 ถึง p50)
('p21','คอนโดหรู ใกล้ BTS อโศก ชั้น 22','คอนโด','กรุงเทพฯ','อโศก สุขุมวิท',6800000,'BUY',2,2,60,0,30,22,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,'คอนโดหรู ห่าง BTS อโศก 150 ม.','a5',ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800'],'2025-07-01'),
('p22','คอนโด BTS สยาม ใกล้ห้างพารากอน','คอนโด','กรุงเทพฯ','สยาม ปทุมวัน',42000,'RENT',2,1,55,0,28,18,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],FALSE,TRUE,'คอนโดพรีเมียม เดิน 3 นาทีถึง BTS','a8',ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],'2025-07-05'),
('p23','คอนโด BTS ชิดลม ย่านเพลินจิต','คอนโด','กรุงเทพฯ','ชิดลม เพลินจิต',55000,'RENT',2,2,75,0,38,28,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],TRUE,TRUE,'คอนโดหรู CBD','a5',ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800'],'2025-07-12'),
('p24','คอนโด BTS พร้อมพงษ์','คอนโด','กรุงเทพฯ','พร้อมพงษ์ คลองเตย',38000,'RENT',2,1,50,0,32,18,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,TRUE,'ใกล้ห้างเอ็มโพเรียม','a8',ARRAY['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],'2025-07-03'),
('p25','คอนโด BTS เอกมัย ห้องมุม','คอนโด','กรุงเทพฯ','เอกมัย วัฒนา',4800000,'BUY',2,1,52,0,30,15,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,TRUE,'คอนโดห้องมุม 2 ห้องนอน','a7',ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800'],'2025-06-28'),
('p26','คอนโด BTS อ่อนนุช','คอนโด','กรุงเทพฯ','อ่อนนุช สุขุมวิท',3100000,'BUY',1,1,33,0,18,10,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'เดิน 5 นาทีถึง BTS','a13',ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],'2025-07-08'),
('p27','คอนโด BTS บางนา ใกล้ Mega','คอนโด','กรุงเทพฯ','บางนา สาทร',2900000,'BUY',1,1,35,0,20,12,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'ใกล้ Mega Bangna','a17',ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],'2025-07-06'),
('p28','คอนโดให้เช่า BTS สะพานควาย','คอนโด','กรุงเทพฯ','สะพานควาย พหลโยธิน',18000,'RENT',1,1,38,0,12,7,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'ย่านกินดื่ม','a19',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-07-10'),
('p29','คอนโด BTS อารีย์','คอนโด','กรุงเทพฯ','อารีย์ พหลโยธิน',5200000,'BUY',2,1,48,0,25,15,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,TRUE,'ย่านคาเฟ่ฮิต','a3',ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],'2025-07-04'),
('p30','บ้านเดี่ยว ใกล้ BTS หมอชิต','บ้านเดี่ยว','กรุงเทพฯ','หมอชิต จตุจักร',9500000,'BUY',4,3,280,70,2,0,3,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,'บ้านเดี่ยวสไตล์โมเดิร์น','a6',ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800'],'2025-07-09'),
('p31','คอนโด BTS วงเวียนใหญ่','คอนโด','กรุงเทพฯ','วงเวียนใหญ่ ธนบุรี',3500000,'BUY',1,1,40,0,22,12,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'ทำเลใหม่ กำลังเติบโต','a20',ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],'2025-06-30'),
('p32','คอนโด BTS กรุงธนบุรี วิวแม่น้ำ','คอนโด','กรุงเทพฯ','กรุงธนบุรี คลองสาน',7800000,'BUY',2,2,65,0,38,30,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],TRUE,TRUE,'วิวแม่น้ำเจ้าพระยา','a5',ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],'2025-07-02'),
('p33','คอนโด MRT พระราม 9','คอนโด','กรุงเทพฯ','พระราม 9 ห้วยขวาง',4200000,'BUY',1,1,40,0,35,25,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,TRUE,'ใกล้ Central พระราม 9','a7',ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'],'2025-06-20'),
('p34','คอนโดให้เช่า MRT สีลม','คอนโด','กรุงเทพฯ','สีลม บางรัก',28000,'RENT',1,1,45,0,30,18,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],FALSE,TRUE,'ย่านธุรกิจ CBD','a2',ARRAY['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],'2025-06-18'),
('p35','คอนโด MRT สุทธิสาร','คอนโด','กรุงเทพฯ','สุทธิสาร ห้วยขวาง',3900000,'BUY',2,1,48,0,28,15,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,TRUE,'ห้องมุมวิวสวน','a3',ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],'2025-06-22'),
('p36','คอนโดให้เช่า MRT ห้วยขวาง','คอนโด','กรุงเทพฯ','ห้วยขวาง รัชดา',16000,'RENT',1,1,35,0,20,12,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'สไตล์ญี่ปุ่น','a20',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-07-07'),
('p37','คอนโดหรู MRT รัชดา','คอนโด','กรุงเทพฯ','รัชดาภิเษก ห้วยขวาง',5500000,'BUY',2,2,65,0,42,32,2,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],TRUE,TRUE,'ชั้น 30+ วิวโล่ง','a3',ARRAY['https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800'],'2025-07-10'),
('p38','คอนโด MRT ลาดพร้าว','คอนโด','กรุงเทพฯ','ลาดพร้าว บึงกุ่ม',4600000,'BUY',2,2,58,0,30,18,1,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,'ใกล้ห้างยูเนี่ยน','a13',ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],'2025-07-06'),
('p39','ทาวน์โฮม ใกล้ MRT จตุจักร','ทาวน์โฮม','กรุงเทพฯ','จตุจักร พหลโยธิน',8500000,'BUY',4,3,220,35,3,0,2,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,TRUE,'Luxury Townhome','a11',ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800'],'2025-06-25'),
('p40','ห้องเช่า ใกล้ จุฬาลงกรณ์','คอนโด','กรุงเทพฯ','สามย่าน ปทุมวัน',14000,'RENT',1,1,32,0,12,8,0,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],FALSE,FALSE,'ห่างจุฬา 500 เมตร','a19',ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],'2025-06-01'),
('p41','คอนโดให้เช่า ใกล้ ม.เกษตร','คอนโด','กรุงเทพฯ','เกษตร-นวมินทร์',8500,'RENT',1,1,28,0,8,5,0,'full',FALSE,ARRAY['แอร์'],TRUE,FALSE,'ใกล้ ม.เกษตรบางเขน','a2',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-05-25'),
('p42','ทาวน์โฮมให้เช่า ใกล้ ม.ธรรมศาสตร์','ทาวน์โฮม','ปทุมธานี','รังสิต คลองหลวง',9500,'RENT',3,2,110,20,2,0,2,'partial',TRUE,ARRAY['แอร์'],TRUE,FALSE,'ใกล้ มธ. รังสิต','a13',ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],'2025-06-08'),
('p43','คอนโดให้เช่า ใกล้ ม.มหิดล','คอนโด','นครปฐม','ศาลายา พุทธมณฑล',6500,'RENT',1,1,24,0,7,4,0,'full',FALSE,ARRAY['แอร์'],TRUE,FALSE,'ราคาประหยัด','a12',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-06-05'),
('p44','คอนโดให้เช่า ใกล้ ม.รังสิต','คอนโด','ปทุมธานี','คลองหลวง ธัญบุรี',7500,'RENT',1,1,26,0,8,5,0,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],FALSE,FALSE,'ใกล้ ม.รังสิต','a13',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-05-28'),
('p45','ห้องเช่า ใกล้ ม.กรุงเทพ','คอนโด','ปทุมธานี','รังสิต ลำลูกกา',7000,'RENT',1,1,28,0,7,4,0,'full',FALSE,ARRAY['แอร์'],FALSE,FALSE,'ใกล้ ม.กรุงเทพ รังสิต','a19',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-06-10'),
('p46','คอนโด ใกล้ ม.ศรีปทุม','คอนโด','กรุงเทพฯ','บางเขน พหลโยธิน',9000,'RENT',1,1,30,0,8,5,0,'full',FALSE,ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,'ใกล้ BTS สะพานควาย','a17',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],'2025-07-01'),
('p47','ทาวน์โฮม ใกล้ นิด้า','ทาวน์โฮม','กรุงเทพฯ','สะพานใหม่ ลาดพร้าว',3800000,'BUY',3,2,140,22,2,0,2,'partial',TRUE,ARRAY['แอร์'],FALSE,FALSE,'ใกล้สถาบันบัณฑิตฯ','a17',ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],'2025-06-15'),
('p48','บ้านเดี่ยวหรู สุขุมวิท 71','บ้านเดี่ยว','กรุงเทพฯ','สุขุมวิท 71 พระโขนง',35000000,'BUY',5,5,500,120,3,0,4,'full',TRUE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์','ระบบรักษาความปลอดภัย'],TRUE,TRUE,'บ้านเดี่ยว Luxury สระว่ายน้ำ','a4',ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800'],'2025-07-02'),
('p49','คอนโดหรู ย่านสาทร','คอนโด','กรุงเทพฯ','สาทร ยานนาวา',12500000,'BUY',3,3,120,0,48,40,2,'full',FALSE,ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โทรทัศน์'],FALSE,TRUE,'Super Luxury วิวแม่น้ำ','a4',ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],'2025-06-25'),
('p50','ที่ดินเปล่า ลาดพร้าว','ที่ดิน','กรุงเทพฯ','ลาดพร้าว บึงกุ่ม',8800000,'BUY',0,0,220,55,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,'ที่ดินทรงสี่เหลี่ยม ใกล้ MRT','a4',ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800'],'2025-05-15')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, province=EXCLUDED.province, location=EXCLUDED.location, price=EXCLUDED.price, tx=EXCLUDED.tx, bed=EXCLUDED.bed, bath=EXCLUDED.bath, area=EXCLUDED.area, land_area=EXCLUDED.land_area, floors=EXCLUDED.floors, floor_no=EXCLUDED.floor_no, parking=EXCLUDED.parking, furniture=EXCLUDED.furniture, pets_allowed=EXCLUDED.pets_allowed, appliances=EXCLUDED.appliances, is_new=EXCLUDED.is_new, is_rec=EXCLUDED.is_rec, description=EXCLUDED.description, agent_id=EXCLUDED.agent_id, photos=EXCLUDED.photos, updated_at=NOW();

-- ============================================================
-- SEED DATA — portfolio (20 ผลงาน)
-- ============================================================
INSERT INTO portfolio (id, title, type, price, status, location, date, review, photo, photos) VALUES
('pt1','บ้านเดี่ยว ร่มเกล้า กรุงเทพฯ','บ้านเดี่ยว',3800000,'SOLD','ร่มเกล้า','ม.ค. 2568','บริการดีมาก','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800']),
('pt2','คอนโด เดอะ ลาม คาราฟ','คอนโด',1900000,'SOLD','อ่อนนุช','ก.พ. 2568','ขายได้เร็ว','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400',ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800']),
('pt3','ทาวน์โฮม ศุภาลัย บางพลี','ทาวน์โฮม',2600000,'SOLD','บางพลี','ก.พ. 2568','ช่วยจัดการเรื่องกู้','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800']),
('pt4','คอนโดให้เช่า สาทร','คอนโด',22000,'RENTED','สาทร','มี.ค. 2568','หาผู้เช่าได้เร็ว','https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400',ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800']),
('pt5','บ้านเดี่ยว พระราม 2','บ้านเดี่ยว',5200000,'SOLD','พระราม 2','มี.ค. 2568','ขายได้ราคาดี','https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=400',ARRAY['https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800']),
('pt6','ที่ดินเปล่า 200 ตร.วา บางนา','ที่ดิน',6200000,'SOLD','บางนา','เม.ย. 2568','ขายภายใน 1 เดือน','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400',ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800']),
('pt7','วิลล่า ภูเก็ต 3 ห้องนอน','วิลล่า',11200000,'SOLD','กะรน ภูเก็ต','พ.ค. 2568','ลูกค้าชาวต่างชาติพอใจ','https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=400',ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800']),
('pt8','คอนโดให้เช่า พระราม 9','คอนโด',18000,'RENTED','พระราม 9','พ.ค. 2568','ผู้เช่าระยะยาว','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=400',ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800']),
('pt9','อาคารพาณิชย์ เพชรบุรี','อาคารพาณิชย์',8200000,'SOLD','เพชรบุรี','มิ.ย. 2568','โอนเรียบร้อย','https://images.unsplash.com/photo-1486325212027-8081e485255e?w=400',ARRAY['https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800']),
('pt10','ทาวน์โฮมให้เช่า รังสิต','ทาวน์โฮม',10000,'RENTED','รังสิต','มิ.ย. 2568','หาผู้เช่าได้เร็ว','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=400',ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800']),
('pt11','บ้านเดี่ยว รามคำแหง','บ้านเดี่ยว',4900000,'SOLD','รามคำแหง','ก.ค. 2568','ขายใน 3 สัปดาห์','https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=400',ARRAY['https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800']),
('pt12','คอนโด เอกมัย 10','คอนโด',4300000,'SOLD','เอกมัย','ก.ค. 2568','ประทับใจบริการ','https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=400',ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800']),
('pt13','ที่ดิน 1 ไร่ ลำลูกกา','ที่ดิน',4200000,'SOLD','ลำลูกกา','ส.ค. 2568','ราคาดีกว่าตลาด','https://images.unsplash.com/photo-1592595896616-c37162298647?w=400',ARRAY['https://images.unsplash.com/photo-1592595896616-c37162298647?w=800']),
('pt14','คอนโดให้เช่า ศรีนครินทร์','คอนโด',13000,'RENTED','ศรีนครินทร์','ส.ค. 2568','ผู้เช่าคุณภาพดี','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=400',ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800']),
('pt15','บ้านเดี่ยว นนทบุรี','บ้านเดี่ยว',3500000,'SOLD','บางบัวทอง','ก.ย. 2568','บริการครบวงจร','https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=400',ARRAY['https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800']),
('pt16','ทาวน์โฮม แจ้งวัฒนะ','ทาวน์โฮม',3100000,'SOLD','แจ้งวัฒนะ','ก.ย. 2568','ขายเร็ว 2 สัปดาห์','https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=400',ARRAY['https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800']),
('pt17','ที่ดิน 2 ไร่ ชลบุรี','ที่ดิน',7900000,'SOLD','พนัสนิคม','ต.ค. 2568','ทำเลดี','https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400',ARRAY['https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800']),
('pt18','คอนโดให้เช่า บางเขน','คอนโด',9500,'RENTED','บางเขน','ต.ค. 2568','ผู้เช่าไว','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=400',ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800']),
('pt19','รีสอร์ท หัวหิน','รีสอร์ท',19500000,'SOLD','หัวหิน','พ.ย. 2568','นักลงทุนพอใจ','https://images.unsplash.com/photo-1582719508461-905c673771fd?w=400',ARRAY['https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800']),
('pt20','วิลล่าให้เช่า หาดราไวย์','วิลล่า',65000,'RENTED','ราไวย์ ภูเก็ต','พ.ย. 2568','ผู้เช่าระยะยาว','https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400',ARRAY['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800'])
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, price=EXCLUDED.price, status=EXCLUDED.status, location=EXCLUDED.location, date=EXCLUDED.date, review=EXCLUDED.review, photo=EXCLUDED.photo, photos=EXCLUDED.photos;

-- ============================================================
-- SEED DATA — services, blogs, legal_pages, site_config
-- ============================================================
INSERT INTO services (id, name, icon, short_desc, full_desc, price, duration, sort_order) VALUES
('ac','ล้างแอร์','fa-wind','ล้างแอร์ทุกประเภท','บริการล้างแอร์คุณภาพสูง','450 บาท/ตัว','1-2 ชั่วโมง',1),
('maid','แม่บ้าน','fa-broom','บริการแม่บ้านคุณภาพ','แม่บ้านผ่านการอบรม','500 บาท/วัน','ตามตกลง',2),
('furn','ซ่อมเฟอร์นิเจอร์','fa-couch','ซ่อมเฟอร์นิเจอร์ทุกชนิด','ซ่อมโต๊ะ เก้าอี้ ตู้ เตียง','300 บาท+','1-3 ชั่วโมง',3),
('plumb','แก้ไขระบบประปา','fa-wrench','แก้ไขปัญหาท่อรั่ว','ช่างมีใบรับรอง','500 บาท+','1-2 ชั่วโมง',4),
('elec','ซ่อมอุปกรณ์ไฟฟ้า','fa-bolt','ซ่อมไฟฟ้าภายในบ้าน','ช่างไฟฟ้ามีใบอนุญาต','400 บาท+','1-3 ชั่วโมง',5),
('door','เปลี่ยนลูกบิดประตู','fa-door-closed','เปลี่ยนลูกบิดทุกแบบ','รวม Smart Lock','250 บาท+','30-60 นาที',6)
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, icon=EXCLUDED.icon, short_desc=EXCLUDED.short_desc, full_desc=EXCLUDED.full_desc, price=EXCLUDED.price, duration=EXCLUDED.duration, sort_order=EXCLUDED.sort_order;

INSERT INTO blogs (title, cat, date, icon, color, content, photos, sort_order, is_published) VALUES
('5 ทำเลทองที่น่าลงทุนปี 2568','การลงทุน','15 พ.ค. 2568','🏆','linear-gradient(135deg,#667eea,#764ba2)','<p>ในปี 2568 ตลาดอสังหาฯ ไทยมีแนวโน้มเติบโต...</p>',ARRAY['https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800'],1,TRUE),
('วิธีเลือกคอนโดใกล้รถไฟฟ้าให้คุ้มค่า','คำแนะนำ','10 พ.ค. 2568','🚇','linear-gradient(135deg,#f093fb,#f5576c)','<p>คอนโดใกล้รถไฟฟ้าเป็นตัวเลือกยอดนิยม...</p>',ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],2,TRUE),
('ขั้นตอนกู้สินเชื่อบ้านสำหรับมือใหม่','สาระน่ารู้','5 พ.ค. 2568','🏦','linear-gradient(135deg,#4facfe,#00f2fe)','<p>การกู้ซื้อบ้านครั้งแรกอาจดูซับซ้อน...</p>',ARRAY['https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800'],3,TRUE),
('เปรียบเทียบ บ้านเดี่ยว vs ทาวน์โฮม','คำแนะนำ','1 พ.ค. 2568','🔍','linear-gradient(135deg,#43e97b,#38f9d7)','<p>ตัดสินใจระหว่างบ้านเดี่ยวกับทาวน์โฮม...</p>',ARRAY['https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800'],4,TRUE),
('เทคนิคต่อรองราคาซื้อบ้าน','เคล็ดลับ','20 เม.ย. 2568','💡','linear-gradient(135deg,#fa709a,#fee140)','<p>รู้เทคนิคง่ายๆ ช่วยประหยัดได้หลายแสน...</p>',ARRAY['https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800'],5,TRUE),
('ข้อควรรู้ก่อนปล่อยเช่าคอนโด','สำหรับผู้ให้เช่า','15 เม.ย. 2568','📋','linear-gradient(135deg,#a18cd1,#fbc2eb)','<p>การปล่อยเช่าคอนโดสร้างรายได้ passive...</p>',ARRAY['https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800'],6,TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO site_config (id, addr, phone, line_id, fb_url, hero_sub, srv_title, srv_sub, yt_url, copyright, tel_url, line_url) VALUES
(1, '123 ถนนสุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110', '061-589-xxxx', '@matchdoor', 'https://facebook.com/matchdoor.official', 'บ้าน คอนโด ที่ดิน ทุกประเภท ทุกทำเล ราคาดีที่สุด', 'บริการครบจบทุกขั้นตอน', 'อยากซื้อ อยากขาย อสังหาฯ ปรึกษาเรา', 'https://www.youtube.com/embed/VUQfT3gNT3g?si=WDXL3fAOPfFaeVFb', '© 2569 Matchdoor — สงวนลิขสิทธิ์', 'tel:061-589-xxxx', 'https://line.me/ti/p/@matchdoor')
ON CONFLICT (id) DO UPDATE SET addr=EXCLUDED.addr, phone=EXCLUDED.phone, line_id=EXCLUDED.line_id, fb_url=EXCLUDED.fb_url, hero_sub=EXCLUDED.hero_sub, srv_title=EXCLUDED.srv_title, srv_sub=EXCLUDED.srv_sub, yt_url=EXCLUDED.yt_url, copyright=EXCLUDED.copyright, tel_url=EXCLUDED.tel_url, line_url=EXCLUDED.line_url, updated_at=NOW();

INSERT INTO legal_pages (id, title, content, version, effective_date) VALUES
('privacy','นโยบายความเป็นส่วนตัว','<h3>1. ข้อมูลที่เราเก็บรวบรวม</h3><p>ชื่อ-นามสกุล เบอร์โทรศัพท์...</p>','2.0','2025-01-01'),
('terms','ข้อกำหนดการใช้งาน','<h3>1. การยอมรับข้อกำหนด</h3><p>การใช้งาน Matchdoor ถือว่ายอมรับ...</p>','2.0','2025-01-01'),
('acceptable_use','นโยบายการใช้งานที่ยอมรับได้','<h3>สิ่งที่ห้ามทำ</h3><ul><li>โพสต์ประกาศเท็จ</li></ul>','1.0','2025-01-01'),
('buy_sell','เงื่อนไขการซื้อ-ขาย','<h3>1. บทบาทของ Matchdoor</h3><p>Matchdoor เป็นตัวกลาง...</p>','2.0','2025-01-01'),
('cookie','นโยบายคุกกี้','<p>เว็บไซต์ของเราใช้คุกกี้เพื่อพัฒนาประสบการณ์...</p>','1.0','2025-01-01')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content=EXCLUDED.content, version=EXCLUDED.version, effective_date=EXCLUDED.effective_date, updated_at=NOW();

-- ============================================================
-- ✅ DONE — Matchdoor Database v5.0 (Complete)
-- ============================================================