-- ============================================================
-- MATCHDOOR — Supabase SQL Schema + Seed Data
-- Version : 5.0 (tag filter popup, agent popup, legal pages seed data, ลบ mock dependency)
-- Updated : 2026 (April) — compatible with MD-029-v2.html
-- HTML Config: SUPABASE_URL ต้องเป็น https://xxx.supabase.co (ไม่ใส่ /rest/v1/)
-- รองรับ  : Supabase Auth, RLS, Full-body Agent Photos,
--            Blog Slider Images, Portfolio Slider, User Forms
-- วิธีใช้  : วางทั้งหมดใน Supabase SQL Editor แล้วกด Run
--            รันซ้ำได้ไม่ error (idempotent)
-- ============================================================

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. ENUM TYPES
--    ใช้ DO Block ป้องกัน error เมื่อรันซ้ำ
-- ============================================================
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

-- ============================================================
-- 2. TABLE: agents
--    HTML ใช้: id, name, title, phone, line_id, initials,
--              color, bio, prop_ids, is_active, avatar_url
--    หมายเหตุ: avatar_url ใช้แสดงรูปเต็มตัวในหน้าตัวแทน
-- ============================================================
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
COMMENT ON TABLE  agents IS 'ตัวแทน/นายหน้าอสังหาริมทรัพย์';
COMMENT ON COLUMN agents.avatar_url  IS 'URL รูปโปรไฟล์ — แสดงแบบเต็มตัวในการ์ดตัวแทน';
COMMENT ON COLUMN agents.prop_ids    IS 'array ของ property id ที่ตัวแทนดูแล (ใช้ fallback ถ้า agent_id ใน properties ไม่ตรง)';
COMMENT ON COLUMN agents.color       IS 'สีพื้นหลัง placeholder เมื่อไม่มี avatar_url';

-- ============================================================
-- 3. TABLE: properties
--    HTML ใช้: id, title, type, province, location, price,
--              tx, bed, bath, area, is_new, is_rec,
--              description, agent_id, photos, created_at
--    หมายเหตุ: photos เป็น text[] — Supabase JS client
--              จะส่งกลับมาเป็น JS Array โดยอัตโนมัติ
-- ============================================================
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
COMMENT ON TABLE  properties IS 'รายการอสังหาริมทรัพย์สำหรับขาย/เช่า';
COMMENT ON COLUMN properties.photos       IS 'URLs รูปภาพหลายรูป — ลำดับแรกใช้เป็น thumbnail บน card';
COMMENT ON COLUMN properties.is_new       IS 'แสดง badge "มาใหม่" บนการ์ด';
COMMENT ON COLUMN properties.is_rec       IS 'แสดงในส่วน "แนะนำ" บนหน้าหลัก';
COMMENT ON COLUMN properties.tx           IS 'BUY = ขาย, RENT = เช่า';
COMMENT ON COLUMN properties.land_area    IS 'ขนาดที่ดิน ตารางวา';
COMMENT ON COLUMN properties.floors       IS 'จำนวนชั้นทั้งหมด';
COMMENT ON COLUMN properties.floor_no     IS 'ชั้นที่ (สำหรับคอนโด/อาคาร)';
COMMENT ON COLUMN properties.parking      IS 'จำนวนที่จอดรถ';
COMMENT ON COLUMN properties.furniture    IS 'การตกแต่งเฟอร์นิเจอร์: none | partial | full';
COMMENT ON COLUMN properties.pets_allowed IS 'อนุญาตเลี้ยงสัตว์';
COMMENT ON COLUMN properties.appliances   IS 'เครื่องใช้ไฟฟ้า เช่น {แอร์,ตู้เย็น,เครื่องซักผ้า}';

-- เพิ่ม columns ใหม่ถ้ายังไม่มี (สำหรับการ run ซ้ำ)
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS land_area    NUMERIC(12,2) DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS floors       INT DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS floor_no     INT DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS parking      INT DEFAULT 0; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS furniture    TEXT DEFAULT ''; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS pets_allowed BOOLEAN DEFAULT FALSE; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties ADD COLUMN IF NOT EXISTS appliances   TEXT[] DEFAULT '{}'; EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================
-- 4. TABLE: portfolio
--    HTML ใช้: id, title, type, price, status, location,
--              date, review, photo, photos
--    หมายเหตุ: photos[] ใช้กับ slider popup — ดึงจาก DB จริง
--              photo ใช้เป็น thumbnail บน gallery card
-- ============================================================
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
COMMENT ON TABLE  portfolio IS 'ผลงานปิดดีล (SOLD/RENTED) — แสดงในหน้าผลงาน';
COMMENT ON COLUMN portfolio.photo   IS 'รูป thumbnail หลัก แสดงบน gallery card';
COMMENT ON COLUMN portfolio.photos  IS 'URLs รูปภาพสำหรับ slider ใน popup — รันซ้ำได้';
COMMENT ON COLUMN portfolio.review  IS 'คำรีวิวจากลูกค้า — แสดงใน popup';
COMMENT ON COLUMN portfolio.date    IS 'วันที่ปิดดีล เช่น "ม.ค. 2568"';

-- ============================================================
-- 5. TABLE: services
--    HTML ใช้: id, name, icon, short_desc, full_desc,
--              price, duration, is_active, sort_order
-- ============================================================
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
COMMENT ON TABLE  services IS 'บริการเสริม เช่น ล้างแอร์ แม่บ้าน ซ่อมบ้าน';
COMMENT ON COLUMN services.icon       IS 'Font Awesome class เช่น fa-wind (ไม่ต้องใส่ fas)';
COMMENT ON COLUMN services.sort_order IS 'ลำดับการแสดงผล — น้อยแสดงก่อน';

-- ============================================================
-- 6. TABLE: blogs
--    HTML ใช้: id, title, cat, date, icon, color,
--              content, photos, is_published, sort_order
--    หมายเหตุ: photos[] ใช้กับ slider popup ใน showBlogDetail()
-- ============================================================
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
COMMENT ON TABLE  blogs IS 'บทความ/สาระน่ารู้ด้านอสังหาฯ';
COMMENT ON COLUMN blogs.icon        IS 'Emoji ไอคอน เช่น 🏆 🚇 🏦';
COMMENT ON COLUMN blogs.color       IS 'CSS gradient สำหรับ thumbnail card';
COMMENT ON COLUMN blogs.photos      IS 'URLs รูปภาพสำหรับ slider popup ใน showBlogDetail()';
COMMENT ON COLUMN blogs.is_published IS 'FALSE = ซ่อนจากหน้าเว็บ';

-- ============================================================
-- 7. TABLE: listings  (ฝากทรัพย์ — จาก submitDep())
--    HTML insert: name, phone, property_type, price,
--                 province, transaction, details,
--                 photos (base64), status, user_id
-- ============================================================
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
  created_at    TIMESTAMPTZ          DEFAULT NOW(),
  updated_at    TIMESTAMPTZ          DEFAULT NOW()
);
COMMENT ON TABLE  listings IS 'แบบฟอร์มฝากทรัพย์จากผู้ใช้งาน (submitDep)';
COMMENT ON COLUMN listings.photos       IS 'รูปภาพเป็น base64 data URL ที่ user อัปโหลด';
COMMENT ON COLUMN listings.transaction  IS 'ขาย หรือ ให้เช่า (Thai text จาก dropdown)';

-- ============================================================
-- 8. TABLE: buy_requests  (ฝากความต้องการ — จาก submitWish())
--    HTML insert: name, phone, line_id, property_type,
--                 budget, province, transaction, details,
--                 status, user_id
-- ============================================================
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
  created_at      TIMESTAMPTZ           DEFAULT NOW(),
  updated_at      TIMESTAMPTZ           DEFAULT NOW()
);
COMMENT ON TABLE  buy_requests IS 'แบบฟอร์มฝากความต้องการซื้อ/เช่าจากผู้ใช้งาน (submitWish)';
COMMENT ON COLUMN buy_requests.matched_prop_id IS 'Admin กรอก property ที่จับคู่แล้ว';

-- ============================================================
-- 9. TABLE: favorites  (รายการโปรด — เก็บฝั่ง server)
--    หมายเหตุ: HTML version นี้ใช้ localStorage เป็นหลัก
--              ตารางนี้ไว้สำหรับ sync เมื่อ user login
-- ============================================================
CREATE TABLE IF NOT EXISTS favorites (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id TEXT        NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, property_id)
);
COMMENT ON TABLE favorites IS 'รายการโปรดของผู้ใช้ (server-side sync)';

-- ============================================================
-- 10. UPDATED_AT TRIGGER
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
  FOR t IN SELECT unnest(ARRAY[
    'agents','properties','blogs','listings','buy_requests'
  ])
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

-- ============================================================
-- 11. ROW LEVEL SECURITY (RLS)
--     Public read : properties, agents, portfolio, services, blogs
--     Auth write  : listings, buy_requests, favorites
-- ============================================================

-- Public read tables
ALTER TABLE properties  ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents      ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio   ENABLE ROW LEVEL SECURITY;
ALTER TABLE services    ENABLE ROW LEVEL SECURITY;
ALTER TABLE blogs       ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_properties" ON properties;
CREATE POLICY "public_read_properties" ON properties
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "public_read_agents" ON agents;
CREATE POLICY "public_read_agents" ON agents
  FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS "public_read_portfolio" ON portfolio;
CREATE POLICY "public_read_portfolio" ON portfolio
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "public_read_services" ON services;
CREATE POLICY "public_read_services" ON services
  FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS "public_read_blogs" ON blogs;
CREATE POLICY "public_read_blogs" ON blogs
  FOR SELECT USING (is_published = TRUE);

-- listings: user เขียน/อ่าน/แก้ไขของตัวเองได้
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "listings_insert_auth" ON listings;
CREATE POLICY "listings_insert_auth" ON listings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "listings_select_own" ON listings;
CREATE POLICY "listings_select_own" ON listings
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "listings_update_own" ON listings;
CREATE POLICY "listings_update_own" ON listings
  FOR UPDATE USING (auth.uid() = user_id);

-- buy_requests: user เขียน/อ่าน/แก้ไขของตัวเองได้
ALTER TABLE buy_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "buyrq_insert_auth" ON buy_requests;
CREATE POLICY "buyrq_insert_auth" ON buy_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "buyrq_select_own" ON buy_requests;
CREATE POLICY "buyrq_select_own" ON buy_requests
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "buyrq_update_own" ON buy_requests;
CREATE POLICY "buyrq_update_own" ON buy_requests
  FOR UPDATE USING (auth.uid() = user_id);

-- favorites: user จัดการของตัวเองได้ทุก operation
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fav_all_own" ON favorites;
CREATE POLICY "fav_all_own" ON favorites
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 12. INDEXES
--     เน้น columns ที่ HTML ใช้ filter/join จริง
-- ============================================================

-- properties
DROP INDEX IF EXISTS idx_properties_tx;
CREATE INDEX idx_properties_tx       ON properties(tx);

DROP INDEX IF EXISTS idx_properties_type;
CREATE INDEX idx_properties_type     ON properties(type);

DROP INDEX IF EXISTS idx_properties_province;
CREATE INDEX idx_properties_province ON properties(province);

DROP INDEX IF EXISTS idx_properties_price;
CREATE INDEX idx_properties_price    ON properties(price);

DROP INDEX IF EXISTS idx_properties_agent;
CREATE INDEX idx_properties_agent    ON properties(agent_id);

DROP INDEX IF EXISTS idx_properties_is_new;
CREATE INDEX idx_properties_is_new   ON properties(is_new) WHERE is_new = TRUE;

DROP INDEX IF EXISTS idx_properties_is_rec;
CREATE INDEX idx_properties_is_rec   ON properties(is_rec) WHERE is_rec = TRUE;

DROP INDEX IF EXISTS idx_properties_created;
CREATE INDEX idx_properties_created  ON properties(created_at DESC);

-- Full-text search สำหรับ ilike query ใน filterProperties
DROP INDEX IF EXISTS idx_properties_title_trgm;
DROP INDEX IF EXISTS idx_properties_loc_trgm;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_properties_title_trgm ON properties USING gin (title gin_trgm_ops);
CREATE INDEX idx_properties_loc_trgm   ON properties USING gin (location gin_trgm_ops);

-- agents
DROP INDEX IF EXISTS idx_agents_active;
CREATE INDEX idx_agents_active ON agents(is_active) WHERE is_active = TRUE;

-- portfolio
DROP INDEX IF EXISTS idx_portfolio_status;
CREATE INDEX idx_portfolio_status  ON portfolio(status);

DROP INDEX IF EXISTS idx_portfolio_type;
CREATE INDEX idx_portfolio_type    ON portfolio(type);

DROP INDEX IF EXISTS idx_portfolio_created;
CREATE INDEX idx_portfolio_created ON portfolio(created_at DESC);

-- blogs
DROP INDEX IF EXISTS idx_blogs_published;
CREATE INDEX idx_blogs_published ON blogs(is_published, sort_order) WHERE is_published = TRUE;

-- services
DROP INDEX IF EXISTS idx_services_active;
CREATE INDEX idx_services_active ON services(is_active, sort_order) WHERE is_active = TRUE;

-- listings
DROP INDEX IF EXISTS idx_listings_user;
CREATE INDEX idx_listings_user   ON listings(user_id);

DROP INDEX IF EXISTS idx_listings_status;
CREATE INDEX idx_listings_status ON listings(status);

-- buy_requests
DROP INDEX IF EXISTS idx_buyrq_user;
CREATE INDEX idx_buyrq_user   ON buy_requests(user_id);

DROP INDEX IF EXISTS idx_buyrq_status;
CREATE INDEX idx_buyrq_status ON buy_requests(status);

-- favorites
DROP INDEX IF EXISTS idx_fav_user;
CREATE INDEX idx_fav_user ON favorites(user_id);

DROP INDEX IF EXISTS idx_fav_prop;
CREATE INDEX idx_fav_prop ON favorites(property_id);

-- ============================================================
-- 13. SEED DATA — agents (20 คน)
--     color ใช้ Gen Z pastel palette ตาม HTML version ใหม่
-- ============================================================
INSERT INTO agents
  (id, name, title, phone, line_id, initials, color, avatar_url)
VALUES
  ('a1' ,'สมชาย มั่นคง'           ,'ผู้จัดการฝ่ายขาย'                    ,'081-234-5678','@somchai'   ,'สม','#7c6fcd','https://randomuser.me/api/portraits/men/1.jpg'),
  ('a2' ,'วารี สุขสันต์'           ,'ที่ปรึกษาอสังหาริมทรัพย์'            ,'082-345-6789','@waree'     ,'วร','#43d9ad','https://randomuser.me/api/portraits/women/2.jpg'),
  ('a3' ,'ประภัส รุ่งเรือง'        ,'ผู้เชี่ยวชาญที่ดิน'                  ,'083-456-7890','@praphat'   ,'ปภ','#6c5ce7','https://randomuser.me/api/portraits/men/3.jpg'),
  ('a4' ,'ณัฐธิดา ใจดี'            ,'ที่ปรึกษา Luxury'                    ,'084-567-8901','@nuttida'   ,'ณธ','#ff6b9d','https://randomuser.me/api/portraits/women/4.jpg'),
  ('a5' ,'ธนากร วัฒนา'             ,'นายหน้าอสังหาฯ'                      ,'085-678-9012','@thanakorn' ,'ธน','#0984e3','https://randomuser.me/api/portraits/men/5.jpg'),
  ('a6' ,'กมลชนก ปรีชา'            ,'ผู้ช่วยผู้จัดการขาย'                 ,'086-789-0123','@kamon'     ,'กม','#d63031','https://randomuser.me/api/portraits/women/6.jpg'),
  ('a7' ,'วิศรุต สมบูรณ์'          ,'ที่ปรึกษาบ้านจัดสรร'                 ,'087-890-1234','@wisarut'   ,'วิ','#ffb347','https://randomuser.me/api/portraits/men/7.jpg'),
  ('a8' ,'สุทธิดา มงคล'            ,'ตัวแทนขายคอนโด'                      ,'088-901-2345','@suttida'   ,'สุ','#e84393','https://randomuser.me/api/portraits/women/8.jpg'),
  ('a9' ,'อภิชาติ ศรีเมือง'        ,'ผู้เชี่ยวชาญอสังหาฯ ภูเก็ต'         ,'089-012-3456','@apichat'   ,'อภ','#5a4fa8','https://randomuser.me/api/portraits/men/9.jpg'),
  ('a10','นริศรา อินทร์สุข'         ,'ที่ปรึกษาการลงทุน'                   ,'080-123-4567','@narisara'  ,'นร','#00cec9','https://randomuser.me/api/portraits/women/10.jpg'),
  ('a11','เจษฎา ทรัพย์เจริญ'       ,'ผู้จัดการฝ่ายขายภาคตะวันออก'        ,'081-234-5670','@jedsada'   ,'เจ','#a855f7','https://randomuser.me/api/portraits/men/11.jpg'),
  ('a12','พิมพ์ชนก เลิศล้ำ'        ,'ตัวแทนขายที่ดิน'                     ,'082-345-6780','@pimchanok' ,'พิ','#fd79a8','https://randomuser.me/api/portraits/women/12.jpg'),
  ('a13','ศุภวิชญ์ ไพบูลย์'        ,'ที่ปรึกษาคอนโดมิเนียม'               ,'083-456-7891','@supawit'   ,'ศุ','#6c5ce7','https://randomuser.me/api/portraits/men/13.jpg'),
  ('a14','ปิยธิดา สุขเกษม'         ,'ผู้ช่วยตัวแทน'                       ,'084-567-8902','@piyathida' ,'ปิ','#ff6b9d','https://randomuser.me/api/portraits/women/14.jpg'),
  ('a15','นันทวัฒน์ จินดา'         ,'นายหน้าอสังหาฯ เชียงใหม่'            ,'085-678-9013','@nuntawat'  ,'นั','#0984e3','https://randomuser.me/api/portraits/men/15.jpg'),
  ('a16','รุ่งทิวา สิริโชค'        ,'ที่ปรึกษาบ้านหรู'                    ,'086-789-0124','@rungtiwa'  ,'รุ','#d63031','https://randomuser.me/api/portraits/women/16.jpg'),
  ('a17','ชญานิศ แก้วใส'           ,'ตัวแทนขายทาวน์โฮม'                   ,'087-890-1235','@chayanis'  ,'ชญ','#ffb347','https://randomuser.me/api/portraits/women/17.jpg'),
  ('a18','ธีรภัทร วงศ์ดี'          ,'ผู้เชี่ยวชาญอสังหาฯ เพื่อการพาณิชย์','088-901-2346','@teerapat'  ,'ธี','#e84393','https://randomuser.me/api/portraits/men/18.jpg'),
  ('a19','กัญญารัตน์ ภักดี'        ,'ที่ปรึกษาด้านการเช่า'                ,'089-012-3457','@kanyarat'  ,'กั','#5a4fa8','https://randomuser.me/api/portraits/women/19.jpg'),
  ('a20','ปวรุตม์ เกียรติกุล'      ,'ผู้จัดการฝ่ายลูกค้าสัมพันธ์'        ,'080-123-4568','@pawarut'   ,'ปว','#00cec9','https://randomuser.me/api/portraits/men/20.jpg')
ON CONFLICT (id) DO UPDATE SET
  name       = EXCLUDED.name,
  title      = EXCLUDED.title,
  phone      = EXCLUDED.phone,
  line_id    = EXCLUDED.line_id,
  initials   = EXCLUDED.initials,
  color      = EXCLUDED.color,
  avatar_url = EXCLUDED.avatar_url,
  updated_at = NOW();

-- ============================================================
-- 14. SEED DATA — properties (20 รายการ)
--     photos[] = รูปหลายรูปสำหรับ slider ใน modal
-- ============================================================
INSERT INTO properties
  (id, title, type, province, location, price, tx, bed, bath, area,
   is_new, is_rec, description, agent_id, photos, created_at)
VALUES
  ('p1','บ้านเดี่ยว 2 ชั้น หมู่บ้านพฤกษา',
   'บ้านเดี่ยว','กรุงเทพฯ','ลาดกระบัง กรุงเทพฯ',
   4500000,'BUY',3,2,180,TRUE,TRUE,
   'บ้านเดี่ยว 2 ชั้น ทำเลดี ใกล้ทางด่วน หมู่บ้านพฤกษาวิลล์ พื้นที่ใช้สอยกว้างขวาง สวนหย่อมหน้าบ้าน',
   'a1',
   ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800',
         'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800',
         'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800'],
   '2025-04-20'),

  ('p2','คอนโด ลุมพินี วิลล์ รัชโยธิน',
   'คอนโด','กรุงเทพฯ','จตุจักร กรุงเทพฯ',
   2200000,'BUY',1,1,35,FALSE,TRUE,
   'คอนโดใกล้รถไฟฟ้า BTS พร้อมอยู่ เฟอร์นิเจอร์ครบ วิวสวย ชั้น 12',
   'a2',
   ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800',
         'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'],
   '2025-03-15'),

  ('p3','ทาวน์โฮม 3 ชั้น ใกล้รถไฟฟ้าสายสีม่วง',
   'ทาวน์โฮม','นนทบุรี','ปากเกร็ด นนทบุรี',
   3200000,'BUY',3,2,140,TRUE,FALSE,
   'โครงการใหม่ ใกล้ MRT สายสีม่วง ห้องกว้าง จอดรถ 2 คัน ทำเลศักยภาพสูง',
   'a3',
   ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800',
         'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800'],
   '2025-05-01'),

  ('p4','ที่ดินเปล่า ติดถนนใหญ่ ทำเลทอง',
   'ที่ดิน','ชลบุรี','บางละมุง ชลบุรี',
   8900000,'BUY',0,0,400,FALSE,TRUE,
   'ที่ดินเปล่า ติดถนน 4 เลน เหมาะลงทุนหรือพัฒนาโครงการ ใกล้นิคมอุตสาหกรรม',
   'a4',
   ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800',
         'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800'],
   '2025-02-10'),

  ('p5','คอนโดให้เช่า แอชตัน อโศก',
   'คอนโด','กรุงเทพฯ','อโศก กรุงเทพฯ',
   35000,'RENT',2,2,65,FALSE,TRUE,
   'คอนโดหรู ใจกลางเมือง ใกล้ BTS อโศก และ MRT สุขุมวิท เฟอร์นิเจอร์ Built-in ทั้งหลัง',
   'a5',
   ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
         'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
         'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800'],
   '2025-04-01'),

  ('p6','บ้านเดี่ยว รามอินทรา กม.8',
   'บ้านเดี่ยว','กรุงเทพฯ','รามอินทรา กรุงเทพฯ',
   5200000,'BUY',4,3,210,TRUE,FALSE,
   'บ้านเดี่ยวสไตล์โมเดิร์น ใกล้ห้างสรรพสินค้า ครัวเปิด พื้น Hardwood ทั้งหลัง',
   'a6',
   ARRAY['https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800',
         'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'],
   '2025-04-25'),

  ('p7','คอนโด ไอดีโอ สาทร',
   'คอนโด','กรุงเทพฯ','สาทร กรุงเทพฯ',
   3800000,'BUY',2,1,45,FALSE,TRUE,
   'คอนโดติด BTS สาทร ชั้น 18 วิวแม่น้ำเจ้าพระยา สระว่ายน้ำ Infinity',
   'a7',
   ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
         'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],
   '2025-03-20'),

  ('p8','ทาวน์โฮม ลาดพร้าว 71',
   'ทาวน์โฮม','กรุงเทพฯ','ลาดพร้าว กรุงเทพฯ',
   3900000,'BUY',3,2,150,TRUE,TRUE,
   'ทาวน์โฮม ใกล้ MRT ลาดพร้าว เดินทางสะดวก ใกล้ห้างยูเนี่ยน',
   'a1',
   ARRAY['https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
         'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800'],
   '2025-05-05'),

  ('p9','วิลล่า 3 ห้องนอน หาดบางเทา',
   'วิลล่า','ภูเก็ต','เชิงทะเล ภูเก็ต',
   12500000,'BUY',3,3,250,TRUE,TRUE,
   'วิลล่าส่วนตัว ห่างชายหาดบางเทา 500 เมตร สระว่ายน้ำส่วนตัว สวนเขตร้อน',
   'a9',
   ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800',
         'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
         'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800'],
   '2025-06-01'),

  ('p10','รีสอร์ท ขนาด 10 ห้อง พัทยา',
   'รีสอร์ท','ชลบุรี','พัทยาใต้ ชลบุรี',
   28000000,'BUY',10,10,800,FALSE,TRUE,
   'รีสอร์ทพร้อมผู้เข้าพัก มีสระว่ายน้ำ ร้านอาหาร ห่างหาดพัทยา 200 เมตร',
   'a10',
   ARRAY['https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
         'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800'],
   '2025-03-01'),

  ('p11','อาคารพาณิชย์ 4 ชั้น ถนนเพชรบุรี',
   'อาคารพาณิชย์','กรุงเทพฯ','เพชรบุรีตัดใหม่',
   9500000,'BUY',0,3,160,FALSE,FALSE,
   'อาคารพาณิชย์ หน้ากว้าง 5 เมตร เหมาะทำธุรกิจ ใกล้ห้างแพลทินัม',
   'a11',
   ARRAY['https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800',
         'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800'],
   '2025-01-15'),

  ('p12','บ้านเดี่ยวให้เช่า บางนา-ตราด',
   'บ้านเดี่ยว','กรุงเทพฯ','บางนา กรุงเทพฯ',
   25000,'RENT',3,2,150,TRUE,TRUE,
   'บ้านเดี่ยว 2 ชั้น ตกแต่งใหม่ ใกล้ Mega Bangna เหมาะครอบครัว',
   'a12',
   ARRAY['https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800',
         'https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800'],
   '2025-06-10'),

  ('p13','คอนโดให้เช่า ใกล้ ม.เกษตรศาสตร์',
   'คอนโด','กรุงเทพฯ','ลาดยาว กรุงเทพฯ',
   12000,'RENT',1,1,30,FALSE,FALSE,
   'คอนโดสตูดิโอ เฟอร์นิเจอร์ครบ อินเตอร์เน็ตฟรี เหมาะนักศึกษา/มนุษย์เงินเดือน',
   'a2',
   ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
   '2025-04-18'),

  ('p14','ทาวน์โฮมให้เช่า รังสิต คลอง 3',
   'ทาวน์โฮม','ปทุมธานี','รังสิต คลอง 3',
   9000,'RENT',2,1,90,TRUE,FALSE,
   'ทาวน์โฮม 2 ชั้น ใกล้ตลาด ใกล้มหาวิทยาลัยรังสิต',
   'a13',
   ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
   '2025-05-20'),

  ('p15','ที่ดินเปล่า 100 ตร.วา พระราม 2',
   'ที่ดิน','กรุงเทพฯ','พระราม 2 ซอย 40',
   5500000,'BUY',0,0,400,FALSE,TRUE,
   'ที่ดินเปล่า หน้ากว้าง 20 เมตร ทรงสี่เหลี่ยม เหมาะสร้างบ้าน/พาณิชย์',
   'a4',
   ARRAY['https://images.unsplash.com/photo-1592595896616-c37162298647?w=800'],
   '2025-02-28'),

  ('p16','คอนโดหรู วิวแม่น้ำ เจริญนคร',
   'คอนโด','กรุงเทพฯ','เจริญนคร',
   8500000,'BUY',2,2,70,TRUE,TRUE,
   'คอนโดระดับลักซ์ชัวรี่ วิวแม่น้ำเจ้าพระยา 180 องศา ใกล้ ICONSIAM',
   'a5',
   ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800',
         'https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800'],
   '2025-06-15'),

  ('p17','บ้านเดี่ยว 2 ชั้น เสรีไทย',
   'บ้านเดี่ยว','กรุงเทพฯ','เสรีไทย มีนบุรี',
   3800000,'BUY',3,2,165,FALSE,FALSE,
   'บ้านเดี่ยว หมู่บ้านนิรันดร์ ทำเลดี ใกล้สนามบินสุวรรณภูมิ',
   'a6',
   ARRAY['https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800'],
   '2025-03-10'),

  ('p18','ที่ดินอุตสาหกรรม 5 ไร่ ฉะเชิงเทรา',
   'ที่ดิน','ฉะเชิงเทรา','บางปะกง',
   25000000,'BUY',0,0,8000,TRUE,TRUE,
   'ที่ดินติดถนนสาย 304 เหมาะสร้างโรงงาน/โกดัง มีไฟฟ้า 3 เฟส น้ำประปา',
   'a10',
   ARRAY['https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800'],
   '2025-05-01'),

  ('p19','คอนโดให้เช่า แถว ม.รังสิต',
   'คอนโด','ปทุมธานี','คลองหลวง',
   8000,'RENT',1,1,28,FALSE,FALSE,
   'คอนโดใกล้มหาวิทยาลัย ราคาประหยัด ปลอดภัย มีรปภ. 24 ชม.',
   'a12',
   ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
   '2025-04-05'),

  ('p20','บ้านเดี่ยวหรู บางพลี',
   'บ้านเดี่ยว','สมุทรปราการ','บางพลี',
   12900000,'BUY',4,4,320,TRUE,TRUE,
   'บ้านเดี่ยวสไตล์อังกฤษ สนามหญ้ากว้าง สระว่ายน้ำส่วนตัว ห้องนอน Master 60 ตร.ม.',
   'a14',
   ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
         'https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800',
         'https://images.unsplash.com/photo-1510627489930-0c1b0bfb6785?w=800'],
   '2025-06-20')
ON CONFLICT (id) DO UPDATE SET
  title       = EXCLUDED.title,
  type        = EXCLUDED.type,
  province    = EXCLUDED.province,
  location    = EXCLUDED.location,
  price       = EXCLUDED.price,
  tx          = EXCLUDED.tx,
  bed         = EXCLUDED.bed,
  bath        = EXCLUDED.bath,
  area        = EXCLUDED.area,
  is_new      = EXCLUDED.is_new,
  is_rec      = EXCLUDED.is_rec,
  description = EXCLUDED.description,
  agent_id    = EXCLUDED.agent_id,
  photos      = EXCLUDED.photos,
  updated_at  = NOW();

-- ============================================================
-- 15. SEED DATA — portfolio (20 ผลงาน)
--     photos[] ใช้กับ slider popup ใน showPortDetail()
-- ============================================================
INSERT INTO portfolio
  (id, title, type, price, status, location, date, review, photo, photos)
VALUES
  ('pt1','บ้านเดี่ยว ร่มเกล้า กรุงเทพฯ',
   'บ้านเดี่ยว',3800000,'SOLD','ร่มเกล้า','ม.ค. 2568',
   'บริการดีมาก โอนได้เร็ว ทีมงานช่วยเรื่องเอกสารทั้งหมด',
   'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',
   ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800',
         'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800',
         'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800']),

  ('pt2','คอนโด เดอะ ลาม คาราฟ',
   'คอนโด',1900000,'SOLD','อ่อนนุช','ก.พ. 2568',
   'ขายได้เร็ว ราคาดีกว่าที่คิด ประทับใจมาก',
   'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400',
   ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800',
         'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800']),

  ('pt3','ทาวน์โฮม ศุภาลัย บางพลี',
   'ทาวน์โฮม',2600000,'SOLD','บางพลี','ก.พ. 2568',
   'ช่วยจัดการเรื่องกู้ได้เลย ประทับใจการบริการ',
   'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
   ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800',
         'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800']),

  ('pt4','คอนโดให้เช่า สาทร',
   'คอนโด',22000,'RENTED','สาทร','มี.ค. 2568',
   'หาผู้เช่าได้ภายใน 2 สัปดาห์ ผู้เช่าคุณภาพดี',
   'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400',
   ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
         'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800']),

  ('pt5','บ้านเดี่ยว พระราม 2',
   'บ้านเดี่ยว',5200000,'SOLD','พระราม 2','มี.ค. 2568',
   'ขายได้ราคาดีมาก เกินความคาดหมาย ขอบคุณทีมงาน',
   'https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=400',
   ARRAY['https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800',
         'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800']),

  ('pt6','ที่ดินเปล่า 200 ตร.วา บางนา',
   'ที่ดิน',6200000,'SOLD','บางนา','เม.ย. 2568',
   'ขายได้ภายใน 1 เดือน ราคาตลาดพอดี',
   'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400',
   ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800',
         'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800']),

  ('pt7','วิลล่า ภูเก็ต 3 ห้องนอน',
   'วิลล่า',11200000,'SOLD','กะรน ภูเก็ต','พ.ค. 2568',
   'ลูกค้าชาวต่างชาติพึงพอใจมาก บริการระดับ Premium',
   'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=400',
   ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800',
         'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
         'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800']),

  ('pt8','คอนโดให้เช่า พระราม 9',
   'คอนโด',18000,'RENTED','พระราม 9','พ.ค. 2568',
   'ได้ผู้เช่าระยะยาว 1 ปี น่าเชื่อถือมาก',
   'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=400',
   ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
         'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800']),

  ('pt9','อาคารพาณิชย์ เพชรบุรี',
   'อาคารพาณิชย์',8200000,'SOLD','เพชรบุรี','มิ.ย. 2568',
   'โอนเรียบร้อย ถูกต้องตามกฎหมาย บริการดีครบวงจร',
   'https://images.unsplash.com/photo-1486325212027-8081e485255e?w=400',
   ARRAY['https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800',
         'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800']),

  ('pt10','ทาวน์โฮมให้เช่า รังสิต',
   'ทาวน์โฮม',10000,'RENTED','รังสิต','มิ.ย. 2568',
   'หาผู้เช่าได้เร็วมาก ภายใน 5 วัน',
   'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=400',
   ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800',
         'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800']),

  ('pt11','บ้านเดี่ยว รามคำแหง',
   'บ้านเดี่ยว',4900000,'SOLD','รามคำแหง','ก.ค. 2568',
   'ขายได้ในราคาที่เจ้าของต้องการ ใช้เวลา 3 สัปดาห์',
   'https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=400',
   ARRAY['https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800',
         'https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800']),

  ('pt12','คอนโด เอกมัย 10',
   'คอนโด',4300000,'SOLD','เอกมัย','ก.ค. 2568',
   'ลูกค้าประทับใจการบริการ จะแนะนำต่อแน่นอน',
   'https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=400',
   ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800',
         'https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800']),

  ('pt13','ที่ดิน 1 ไร่ ลำลูกกา',
   'ที่ดิน',4200000,'SOLD','ลำลูกกา','ส.ค. 2568',
   'ขายได้ราคาดี เหนือราคาตั้ง 8%',
   'https://images.unsplash.com/photo-1592595896616-c37162298647?w=400',
   ARRAY['https://images.unsplash.com/photo-1592595896616-c37162298647?w=800']),

  ('pt14','คอนโดให้เช่า ศรีนครินทร์',
   'คอนโด',13000,'RENTED','ศรีนครินทร์','ส.ค. 2568',
   'ได้ผู้เช่าที่น่าเชื่อถือ พนักงานบริษัทใหญ่',
   'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=400',
   ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800',
         'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800']),

  ('pt15','บ้านเดี่ยว นนทบุรี',
   'บ้านเดี่ยว',3500000,'SOLD','บางบัวทอง','ก.ย. 2568',
   'บริการดี ครบวงจร จัดการเรื่องโอนให้ทั้งหมด',
   'https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=400',
   ARRAY['https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800',
         'https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800']),

  ('pt16','ทาวน์โฮม แจ้งวัฒนะ',
   'ทาวน์โฮม',3100000,'SOLD','แจ้งวัฒนะ','ก.ย. 2568',
   'ขายได้ในเวลาอันรวดเร็ว ภายใน 2 สัปดาห์',
   'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=400',
   ARRAY['https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800']),

  ('pt17','ที่ดิน 2 ไร่ ชลบุรี',
   'ที่ดิน',7900000,'SOLD','พนัสนิคม','ต.ค. 2568',
   'ลูกค้าพอใจในทำเล เหมาะสร้างโรงงานมาก',
   'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400',
   ARRAY['https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800']),

  ('pt18','คอนโดให้เช่า บางเขน',
   'คอนโด',9500,'RENTED','บางเขน','ต.ค. 2568',
   'ได้ผู้เช่าอย่างรวดเร็ว ภายใน 1 สัปดาห์',
   'https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=400',
   ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800']),

  ('pt19','รีสอร์ท หัวหิน',
   'รีสอร์ท',19500000,'SOLD','หัวหิน','พ.ย. 2568',
   'ขายได้ทั้งรีสอร์ทในราคาดี นักลงทุนพอใจมาก',
   'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=400',
   ARRAY['https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
         'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800',
         'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800']),

  ('pt20','วิลล่าให้เช่า หาดราไวย์',
   'วิลล่า',65000,'RENTED','ราไวย์ ภูเก็ต','พ.ย. 2568',
   'ได้ผู้เช่าระยะยาว 6 เดือน ชาวต่างชาติ',
   'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400',
   ARRAY['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
         'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800'])
ON CONFLICT (id) DO UPDATE SET
  title    = EXCLUDED.title,
  type     = EXCLUDED.type,
  price    = EXCLUDED.price,
  status   = EXCLUDED.status,
  location = EXCLUDED.location,
  date     = EXCLUDED.date,
  review   = EXCLUDED.review,
  photo    = EXCLUDED.photo,
  photos   = EXCLUDED.photos;

-- ============================================================
-- 16. SEED DATA — services (6 บริการ)
-- ============================================================
INSERT INTO services
  (id, name, icon, short_desc, full_desc, price, duration, sort_order)
VALUES
  ('ac',   'ล้างแอร์',           'fa-wind',       'ล้างแอร์ทุกประเภท',        'บริการล้างแอร์ทุกประเภท ทั้งแอร์บ้านและแอร์สำนักงาน รับประกันงาน 30 วัน ใช้น้ำยาคุณภาพสูง ไม่ทำลายคอยล์',    '450 บาท/ตัว', '1-2 ชั่วโมง', 1),
  ('maid', 'แม่บ้าน',            'fa-broom',      'บริการแม่บ้านคุณภาพ',      'บริการแม่บ้านคุณภาพ ผ่านการอบรมและตรวจสอบประวัติอาชญากรรม มีทั้งรายวัน รายสัปดาห์ รายเดือน ประกันการทำงาน', '500 บาท/วัน', 'ตามตกลง',     2),
  ('furn', 'ซ่อมเฟอร์นิเจอร์',  'fa-couch',      'ซ่อมเฟอร์นิเจอร์ทุกชนิด', 'ซ่อมเฟอร์นิเจอร์ทุกชนิด โต๊ะ เก้าอี้ ตู้ เตียง รวมถึงเฟอร์นิเจอร์ Built-in พร้อมเปลี่ยนอะไหล่ใหม่',   '300 บาท+',    '1-3 ชั่วโมง', 3),
  ('plumb','แก้ไขระบบประปา',    'fa-wrench',     'แก้ไขปัญหาท่อรั่ว',        'แก้ไขปัญหาท่อรั่ว อุดตัน เปลี่ยนวาล์ว ติดตั้งระบบประปาใหม่ รับประกันงาน 90 วัน ช่างมีใบรับรอง',          '500 บาท+',    '1-2 ชั่วโมง', 4),
  ('elec', 'ซ่อมอุปกรณ์ไฟฟ้า', 'fa-bolt',       'ซ่อมไฟฟ้าภายในบ้าน',      'ซ่อมไฟฟ้าภายในบ้าน เดินสายใหม่ เปลี่ยนสวิตช์ ปลั๊ก ระบบไฟส่องสว่าง ช่างไฟฟ้ามีใบอนุญาต กปภ.',            '400 บาท+',    '1-3 ชั่วโมง', 5),
  ('door', 'เปลี่ยนลูกบิดประตู','fa-door-closed','เปลี่ยนลูกบิดทุกแบบ',      'เปลี่ยนลูกบิดประตูทุกแบบ ทั้งธรรมดา บานเลื่อน และดิจิตอล Smart Lock พร้อมติดตั้งและทดสอบ',                  '250 บาท+',    '30-60 นาที',  6)
ON CONFLICT (id) DO UPDATE SET
  name       = EXCLUDED.name,
  icon       = EXCLUDED.icon,
  short_desc = EXCLUDED.short_desc,
  full_desc  = EXCLUDED.full_desc,
  price      = EXCLUDED.price,
  duration   = EXCLUDED.duration,
  sort_order = EXCLUDED.sort_order;

-- ============================================================
-- 17. SEED DATA — blogs (6 บทความ พร้อม photos[] สำหรับ slider)
-- ============================================================
INSERT INTO blogs
  (title, cat, date, icon, color, content, photos, sort_order, is_published)
VALUES
  (
    '5 ทำเลทองที่น่าลงทุนปี 2568',
    'การลงทุน', '15 พ.ค. 2568', '🏆',
    'linear-gradient(135deg,#667eea,#764ba2)',
    '<p>ในปี 2568 ตลาดอสังหาริมทรัพย์ไทยมีแนวโน้มเติบโตอย่างต่อเนื่อง โดยเฉพาะทำเลที่เชื่อมต่อระบบขนส่งมวลชนและโครงการภาครัฐ เราคัด 5 ทำเลที่น่าจับตามอง:</p>
    <ul>
      <li><strong>บางนา-ตราด</strong> : เชื่อมกรุงเทพฯ-ชลบุรี มีโครงการรถไฟฟ้าสายสีเหลืองและทางพิเศษ</li>
      <li><strong>บางใหญ่ (นนทบุรี)</strong> : รถไฟฟ้าสายสีม่วงขยายเส้นทาง เชื่อมต่อสีแดง</li>
      <li><strong>ศรีราชา-พัทยา</strong> : เขตเศรษฐกิจพิเศษตะวันออก (EEC)</li>
      <li><strong>เชียงใหม่ (เชิงดอย)</strong> : วิลล่าและบ้านพักตากอากาศกำลังมาแรง</li>
      <li><strong>ภูเก็ต (กะรน-บางเทา)</strong> : ความต้องการคอนโดและวิลล่าจากชาวต่างชาติฟื้นตัวสูง</li>
    </ul>
    <p>ควรศึกษาระยะเวลาเปิดโครงการ ภาวะเศรษฐกิจ และอัตราดอกเบี้ยก่อนตัดสินใจลงทุน</p>',
    ARRAY[
      'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800',
      'https://images.unsplash.com/photo-1448630360428-65456885c650?w=800',
      'https://images.unsplash.com/photo-1582407947304-fd86f028f716?w=800'
    ],
    1, TRUE
  ),
  (
    'วิธีเลือกคอนโดใกล้รถไฟฟ้าให้คุ้มค่า',
    'คำแนะนำ', '10 พ.ค. 2568', '🚇',
    'linear-gradient(135deg,#f093fb,#f5576c)',
    '<p>คอนโดใกล้รถไฟฟ้าเป็นตัวเลือกยอดนิยม แต่จะเลือกอย่างไรให้คุ้มค่าที่สุด?</p>
    <ul>
      <li><strong>ระยะเดินถึง BTS/MRT</strong> : ควรอยู่ในรัศมี 500 เมตร หรือมีรถ shuttle</li>
      <li><strong>ราคาต่อตารางเมตร</strong> : เทียบกับทำเลใกล้เคียง ถ้าแพงกว่าเกิน 20% ควรพิจารณา</li>
      <li><strong>ส่วนกลางและค่าส่วนกลาง</strong> : สระว่ายน้ำ ฟิตเนส ที่จอดรถ ค่าใช้จ่ายต่อเดือน</li>
      <li><strong>ผู้ประกอบการ</strong> : เลือกแบรนด์ดังที่มีประกันหลังการขายดี</li>
      <li><strong>การเติบโตในอนาคต</strong> : ทำเลที่กำลังมีห้างใหม่ หรือสถานีเชื่อมต่อ</li>
    </ul>
    <p>แนะนำให้ทดลองเดินทางช่วงชั่วโมงเร่งด่วนก่อนตัดสินใจ</p>',
    ARRAY[
      'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800',
      'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=800'
    ],
    2, TRUE
  ),
  (
    'ขั้นตอนกู้สินเชื่อบ้านสำหรับมือใหม่',
    'สาระน่ารู้', '5 พ.ค. 2568', '🏦',
    'linear-gradient(135deg,#4facfe,#00f2fe)',
    '<p>การกู้ซื้อบ้านครั้งแรกอาจดูซับซ้อน แต่ถ้าเข้าใจขั้นตอนก็ไม่ยาก</p>
    <ol>
      <li><strong>ตรวจสอบคุณสมบัติและเครดิตบูโร</strong></li>
      <li><strong>เลือกธนาคารและยื่นใบกู้เบื้องต้น</strong> : ติดต่อหลายธนาคารเพื่อเปรียบเทียบ</li>
      <li><strong>เตรียมเอกสาร</strong> : สลิปเงินเดือน บัตรประชาชน ทะเบียนบ้าน Statement 6 เดือน</li>
      <li><strong>ธนาคารประเมินทรัพย์</strong> : ส่งเจ้าหน้าที่ไปประเมินราคา</li>
      <li><strong>อนุมัติสินเชื่อและทำสัญญา</strong> : ระยะเวลาประมาณ 2-4 สัปดาห์</li>
      <li><strong>จดจำนองที่กรมที่ดิน</strong> : พร้อมรับโอนกรรมสิทธิ์</li>
    </ol>
    <p>เคล็ดลับ: รักษาเครดิตให้ดี ไม่สร้างหนี้ใหม่ระหว่างรออนุมัติ</p>',
    ARRAY[
      'https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800',
      'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800'
    ],
    3, TRUE
  ),
  (
    'เปรียบเทียบ บ้านเดี่ยว vs ทาวน์โฮม แบบเจาะลึก',
    'คำแนะนำ', '1 พ.ค. 2568', '🔍',
    'linear-gradient(135deg,#43e97b,#38f9d7)',
    '<p>กำลังตัดสินใจระหว่างบ้านเดี่ยวกับทาวน์โฮม? ลองดูข้อดี-ข้อเสีย</p>
    <table border="0" cellpadding="6" style="width:100%;border-collapse:collapse;font-size:13px">
      <tr style="background:#f0eeff"><th>คุณสมบัติ</th><th>บ้านเดี่ยว</th><th>ทาวน์โฮม</th></tr>
      <tr><td>พื้นที่ใช้สอย</td><td>กว้างขวาง มีที่ดินรอบบ้าน</td><td>จำกัด แนวตั้ง 2-3 ชั้น</td></tr>
      <tr><td>ความเป็นส่วนตัว</td><td>สูง (ไม่มีผนังร่วม)</td><td>ปานกลาง</td></tr>
      <tr><td>ราคาเริ่มต้น</td><td>3-5 ล้านบาท+</td><td>1.5-3 ล้านบาท</td></tr>
      <tr><td>ทำเล</td><td>มักอยู่ในซอยลึก</td><td>มักติดถนนใหญ่</td></tr>
    </table>
    <p>สรุป: เลือกบ้านเดี่ยวถ้าต้องการพื้นที่ เลือกทาวน์โฮมถ้างบจำกัดแต่ต้องการทำเลดี</p>',
    ARRAY[
      'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
      'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800',
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800'
    ],
    4, TRUE
  ),
  (
    'เทคนิคต่อรองราคาซื้อบ้านให้ได้ถูกกว่า',
    'เคล็ดลับ', '20 เม.ย. 2568', '💡',
    'linear-gradient(135deg,#fa709a,#fee140)',
    '<p>หลายคนซื้อบ้านครั้งแรกไม่กล้าต่อราคา แต่ถ้ารู้เทคนิคง่ายๆ จะช่วยประหยัดได้หลายแสน</p>
    <ul>
      <li><strong>รู้ราคาตลาด</strong> : ศึกษาโครงการใกล้เคียงจากหลายแหล่ง</li>
      <li><strong>เลือกเวลาที่เหมาะสม</strong> : ปลายปีเจ้าของมักต้องการปิดบัญชี</li>
      <li><strong>แสดงความสนใจแต่ไม่เร่งรีบ</strong> : บอกว่ามีตัวเลือกอื่น</li>
      <li><strong>เสนอราคาต่ำกว่า 10-15%</strong> แล้วค่อยๆ ปรับขึ้น</li>
      <li><strong>ใช้เงินสดเป็นข้อต่อรอง</strong> : ขอส่วนลดพิเศษได้</li>
    </ul>
    <p>อย่าลืมทำสัญญาเป็นลายลักษณ์อักษร และระบุวันโอนให้ชัดเจน</p>',
    ARRAY[
      'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800',
      'https://images.unsplash.com/photo-1560185008-c5f8f924cde9?w=800'
    ],
    5, TRUE
  ),
  (
    'ข้อควรรู้ก่อนปล่อยเช่าคอนโด',
    'สำหรับผู้ให้เช่า', '15 เม.ย. 2568', '📋',
    'linear-gradient(135deg,#a18cd1,#fbc2eb)',
    '<p>การปล่อยเช่าคอนโดสร้างรายได้ passive แต่ต้องระวังปัญหาที่อาจเกิดขึ้น</p>
    <ul>
      <li><strong>ตรวจสอบผู้เช่า</strong> : ขอสำเนาบัตรประชาชน ทะเบียนบ้าน สลิปเงินเดือน</li>
      <li><strong>ทำสัญญาเช่าชัดเจน</strong> : ระบุระยะเวลา ค่าเช่า ค่าประกัน ข้อห้าม</li>
      <li><strong>ถ่ายรูปสภาพห้องก่อนเข้า</strong> : ใช้เป็นหลักฐานเมื่อส่งคืน</li>
      <li><strong>กำหนดเงื่อนไขการซ่อมแซม</strong> : ความเสียหายจากผู้เช่าต้องรับผิดชอบ</li>
      <li><strong>แจ้งนิติบุคคล</strong> : บางโครงการมีข้อกำหนดเพิ่มเติม</li>
    </ul>
    <p>การมีสัญญาที่รัดกุมและประกันภัยจะช่วยป้องกันความเสี่ยง</p>',
    ARRAY[
      'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
      'https://images.unsplash.com/photo-1560185008-c5f8f924cde9?w=800'
    ],
    6, TRUE
  )
ON CONFLICT DO NOTHING;

-- ============================================================
-- 18. VIEWS (Helper สำหรับ Admin Dashboard)
-- ============================================================

-- View รวม properties + agent info (ใช้ใน admin panel)
DROP VIEW IF EXISTS v_properties_with_agent;
CREATE VIEW v_properties_with_agent AS
SELECT
  p.*,
  a.name       AS agent_name,
  a.title      AS agent_title,
  a.phone      AS agent_phone,
  a.line_id    AS agent_line_id,
  a.initials   AS agent_initials,
  a.color      AS agent_color,
  a.avatar_url AS agent_avatar
FROM properties p
LEFT JOIN agents a ON a.id = p.agent_id;

-- View สรุปภาพรวมสำหรับ Dashboard
DROP VIEW IF EXISTS v_dashboard_summary;
CREATE VIEW v_dashboard_summary AS
SELECT
  (SELECT COUNT(*)    FROM properties)                            AS total_properties,
  (SELECT COUNT(*)    FROM properties WHERE tx  = 'BUY')         AS for_sale,
  (SELECT COUNT(*)    FROM properties WHERE tx  = 'RENT')         AS for_rent,
  (SELECT COUNT(*)    FROM properties WHERE is_new = TRUE)        AS new_listings,
  (SELECT COUNT(*)    FROM properties WHERE is_rec = TRUE)        AS recommended,
  (SELECT COUNT(*)    FROM agents     WHERE is_active = TRUE)     AS total_agents,
  (SELECT COUNT(*)    FROM portfolio)                             AS total_deals,
  (SELECT COUNT(*)    FROM portfolio  WHERE status = 'SOLD')      AS sold_count,
  (SELECT COUNT(*)    FROM portfolio  WHERE status = 'RENTED')    AS rented_count,
  (SELECT COUNT(*)    FROM listings   WHERE status = 'รอตรวจสอบ') AS pending_listings,
  (SELECT COUNT(*)    FROM buy_requests WHERE status = 'ใหม่')   AS new_requests;

-- View สรุปผลงานแต่ละตัวแทน
DROP VIEW IF EXISTS v_agent_performance;
CREATE VIEW v_agent_performance AS
SELECT
  a.id,
  a.name,
  a.title,
  a.phone,
  a.avatar_url,
  COUNT(DISTINCT p.id) AS active_properties,
  COUNT(DISTINCT po.id) AS total_deals
FROM agents a
LEFT JOIN properties p  ON p.agent_id = a.id
LEFT JOIN portfolio  po ON po.id IS NOT NULL -- placeholder join
WHERE a.is_active = TRUE
GROUP BY a.id, a.name, a.title, a.phone, a.avatar_url;

-- ============================================================
-- 19. STORAGE BUCKET SETUP (สำหรับ Supabase Storage)
--     รัน section นี้ใน Supabase Dashboard > Storage
--     หรือใช้ SQL ด้านล่างถ้า Storage extension ถูก enable
-- ============================================================

-- สร้าง bucket สำหรับรูปภาพ properties (ถ้ายังไม่มี)
INSERT INTO storage.buckets (id, name, public)
VALUES ('property-images', 'property-images', TRUE)
ON CONFLICT (id) DO NOTHING;

-- สร้าง bucket สำหรับรูปภาพ agents
INSERT INTO storage.buckets (id, name, public)
VALUES ('agent-avatars', 'agent-avatars', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Policy: ทุกคนอ่านได้
DROP POLICY IF EXISTS "public_read_property_images" ON storage.objects;
CREATE POLICY "public_read_property_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'property-images');

DROP POLICY IF EXISTS "public_read_agent_avatars" ON storage.objects;
CREATE POLICY "public_read_agent_avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'agent-avatars');

-- Policy: user ที่ login อัปโหลดได้เฉพาะ bucket ของตัวเอง
DROP POLICY IF EXISTS "auth_upload_property_images" ON storage.objects;
CREATE POLICY "auth_upload_property_images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'property-images' AND auth.role() = 'authenticated'
  );

-- ============================================================

-- ============================================================
-- 20. TABLE: site_config
--     ใช้เก็บ config หน้าเว็บที่ Admin แก้ไขได้
--     HTML ใช้: addr, phone, line_id, fb_url, hero_sub,
--               srv_title, srv_sub, yt_url, copyright
-- ============================================================
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
  updated_at  TIMESTAMPTZ   DEFAULT NOW(),
  CONSTRAINT  site_config_single CHECK (id = 1)  -- บังคับมีแค่ 1 row
);
COMMENT ON TABLE site_config IS 'ตั้งค่าเว็บไซต์ที่ Admin แก้ไขได้ผ่าน Admin Panel';

-- Seed default config
INSERT INTO site_config (id, addr, phone, line_id, fb_url, hero_sub, srv_title, srv_sub, yt_url, copyright)
VALUES (1,
  '123 ถนนสุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
  '061-589-xxxx',
  '@matchdoor',
  'https://facebook.com/matchdoor.official',
  'บ้าน คอนโด ที่ดิน ทุกประเภท ทุกทำเล ราคาดีที่สุด',
  'บริการครบจบทุกขั้นตอน',
  'อยากซื้อ อยากขาย อสังหาฯ ปรึกษาเรา',
  'https://www.youtube.com/embed/VUQfT3gNT3g?si=WDXL3fAOPfFaeVFb',
  '© 2569 Matchdoor — สงวนลิขสิทธิ์'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 21. TABLE: admin_users
--     เก็บ email ที่มีสิทธิ์เป็น Admin
--     (ใช้ร่วมกับ Supabase Auth)
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_users (
  id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID          UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT          NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ   DEFAULT NOW()
);
COMMENT ON TABLE admin_users IS 'รายชื่อ email ที่มีสิทธิ์ Admin';

-- เพิ่ม Admin email ที่นี่ (ต้องมี account ใน Supabase Auth ก่อน)
-- INSERT INTO admin_users (email) VALUES ('admin@matchdoor.co.th')
-- ON CONFLICT DO NOTHING;

-- ============================================================
-- 22. RLS: site_config
--     Public read / Admin write only
-- ============================================================
ALTER TABLE site_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_site_config" ON site_config;
CREATE POLICY "public_read_site_config" ON site_config
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "admin_write_site_config" ON site_config;
CREATE POLICY "admin_write_site_config" ON site_config
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE user_id = auth.uid()
    )
  );

-- ============================================================
-- 23. RLS: Admin write policies สำหรับ tables หลัก
--     Admin (ใน admin_users) สามารถ write ทุก table ได้
-- ============================================================

-- Helper function: check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_users
    WHERE user_id = auth.uid()
  );
$$;

-- properties: admin full access
DROP POLICY IF EXISTS "admin_all_properties" ON properties;
CREATE POLICY "admin_all_properties" ON properties
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- agents: admin full access
DROP POLICY IF EXISTS "admin_all_agents" ON agents;
CREATE POLICY "admin_all_agents" ON agents
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- portfolio: admin full access
DROP POLICY IF EXISTS "admin_all_portfolio" ON portfolio;
CREATE POLICY "admin_all_portfolio" ON portfolio
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- services: admin full access
DROP POLICY IF EXISTS "admin_all_services" ON services;
CREATE POLICY "admin_all_services" ON services
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- blogs: admin full access (รวมถึง is_published = FALSE)
DROP POLICY IF EXISTS "admin_all_blogs" ON blogs;
CREATE POLICY "admin_all_blogs" ON blogs
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- listings: admin read/update all
DROP POLICY IF EXISTS "admin_all_listings" ON listings;
CREATE POLICY "admin_all_listings" ON listings
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- buy_requests: admin read/update all
DROP POLICY IF EXISTS "admin_all_buyrq" ON buy_requests;
CREATE POLICY "admin_all_buyrq" ON buy_requests
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- admin_users: admin only
DROP POLICY IF EXISTS "admin_read_admin_users" ON admin_users;
CREATE POLICY "admin_read_admin_users" ON admin_users
  FOR SELECT USING (is_admin());

-- ============================================================
-- 24. INDEXES เพิ่มเติม
-- ============================================================
DROP INDEX IF EXISTS idx_site_config_id;
CREATE INDEX idx_site_config_id ON site_config(id);

DROP INDEX IF EXISTS idx_admin_users_email;
CREATE INDEX idx_admin_users_email ON admin_users(email);

DROP INDEX IF EXISTS idx_admin_users_userid;
CREATE INDEX idx_admin_users_userid ON admin_users(user_id);

-- ============================================================
-- 25. VIEW: v_site_config_public
--     Public view สำหรับ HTML ดึง config
-- ============================================================
DROP VIEW IF EXISTS v_site_config_public;
CREATE VIEW v_site_config_public AS
SELECT addr, phone, line_id, fb_url, hero_sub,
       srv_title, srv_sub, yt_url, copyright, updated_at
FROM site_config WHERE id = 1;

-- ============================================================
-- 26. HELPER: วิธีตั้งค่า Admin Email
-- ============================================================
-- ขั้นตอน:
-- 1. สร้าง user ใน Supabase Dashboard > Authentication > Users
--    (หรือ signUp ผ่าน API ก็ได้)
-- 2. Copy UUID ของ user นั้น
-- 3. รัน SQL ด้านล่าง แทนที่ UUID และ email:
--
-- INSERT INTO admin_users (user_id, email)
-- VALUES ('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'admin@matchdoor.co.th')
-- ON CONFLICT DO NOTHING;
--
-- 4. แก้ไข ADMIN_EMAILS ใน HTML ให้ตรงกัน:
--    const ADMIN_EMAILS = ['admin@matchdoor.co.th'];
--
-- 5. กด Admin FAB (🛡️) ที่มุมล่างขวาของหน้าเว็บ → Login
-- ============================================================

-- ✅ DONE — Matchdoor Database v3.0
-- ============================================================
-- Tables    : properties, agents, portfolio, services,
--             blogs, listings, buy_requests, favorites,
--             site_config (NEW), admin_users (NEW)
-- Views     : v_properties_with_agent, v_dashboard_summary,
--             v_agent_performance, v_site_config_public (NEW)
-- Functions : is_admin(), set_updated_at()
-- Storage   : property-images, agent-avatars (public buckets)
-- RLS       : เปิดใช้งานครบ + Admin write policies
--             — public read: properties, agents, portfolio,
--               services, blogs, site_config
--             — admin write: ทุก table (via admin_users)
--             — auth write: listings, buy_requests, favorites
-- Indexes   : ครบทุก column + site_config + admin_users
-- Seed Data : agents ×20, properties ×20, portfolio ×20,
--             services ×6, blogs ×6, site_config ×1
--             ทุก record มี ON CONFLICT DO UPDATE (idempotent)
-- Admin     : ตั้งค่าผ่าน admin_users table
--             แก้ไขข้อมูล properties/agents/portfolio/blogs/
--             services/site_config ได้ผ่าน Admin Panel
-- ============================================================

-- ============================================================
-- 27. ALTER: เพิ่ม consent_given ใน listings & buy_requests
--     (HTML submitDep() และ submitWish() ส่ง consent_given=true)
-- ============================================================
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS consent_given    BOOLEAN     DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS consent_timestamp TIMESTAMPTZ;

ALTER TABLE buy_requests
  ADD COLUMN IF NOT EXISTS consent_given    BOOLEAN     DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS consent_timestamp TIMESTAMPTZ;

COMMENT ON COLUMN listings.consent_given      IS 'ผู้ใช้ยอมรับ PDPA consent ก่อนส่งข้อมูล';
COMMENT ON COLUMN buy_requests.consent_given  IS 'ผู้ใช้ยอมรับ PDPA consent ก่อนส่งข้อมูล';

-- ============================================================
-- 28. TABLE: legal_pages
--     เก็บเนื้อหา: นโยบายความเป็นส่วนตัว, ข้อตกลงฯ,
--     นโยบายการใช้งานที่ยอมรับได้, เงื่อนไขซื้อ-ขาย,
--     นโยบายคุกกี้ — แก้ไขได้ผ่าน Admin โดยไม่ต้องแก้ HTML
--     HTML เรียกใช้ผ่าน loadLegalPages() → inject เข้า modal
-- ============================================================
CREATE TABLE IF NOT EXISTS legal_pages (
  id              TEXT        PRIMARY KEY,
  title           TEXT        NOT NULL,
  content         TEXT        NOT NULL,
  version         TEXT        DEFAULT '1.0',
  effective_date  TEXT,
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_by      TEXT
);
COMMENT ON TABLE legal_pages IS 'เนื้อหานโยบายทางกฎหมาย — แก้ไขได้โดย Admin ไม่ต้องแตะ HTML';
COMMENT ON COLUMN legal_pages.id      IS 'slug: privacy | terms | acceptable_use | buy_sell | cookie';
COMMENT ON COLUMN legal_pages.content IS 'HTML content ที่ inject เข้า modal โดยตรง';

-- RLS: public read
ALTER TABLE legal_pages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_legal" ON legal_pages;
CREATE POLICY "public_read_legal" ON legal_pages
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "admin_write_legal" ON legal_pages;
CREATE POLICY "admin_write_legal" ON legal_pages
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- Updated_at trigger
DO $$ BEGIN
  EXECUTE 'DROP TRIGGER IF EXISTS trg_updated_at ON legal_pages;
    CREATE TRIGGER trg_updated_at
    BEFORE UPDATE ON legal_pages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();';
END $$;

-- Index
DROP INDEX IF EXISTS idx_legal_pages_id;
CREATE INDEX idx_legal_pages_id ON legal_pages(id);

-- ============================================================
-- 29. SEED DATA — legal_pages (5 นโยบาย)
--     HTML modal ids: privacy-modal, terms-modal,
--     acceptable-use-modal, buysell-modal, cookie-modal
-- ============================================================
INSERT INTO legal_pages (id, title, content, version, effective_date) VALUES

('privacy',
 'นโยบายความเป็นส่วนตัว (Privacy Policy)',
 '<div class="highlight-box" style="margin-bottom:16px">
  <strong>บังคับใช้ตาม:</strong> พ.ร.บ.คุ้มครองข้อมูลส่วนบุคคล (PDPA) พ.ศ. 2562 | <strong>มีผลบังคับ:</strong> 1 มกราคม 2568
</div>
<h3>1. ข้อมูลที่เราเก็บรวบรวม</h3>
<p><strong>ข้อมูลที่คุณให้โดยตรง:</strong></p>
<ul>
  <li>ชื่อ-นามสกุล เบอร์โทรศัพท์ อีเมล Line ID</li>
  <li>รายละเอียดความต้องการอสังหาริมทรัพย์ (ประเภท งบประมาณ ทำเล)</li>
  <li>ข้อมูลทรัพย์สินที่ต้องการฝากขาย/เช่า พร้อมรูปภาพ</li>
  <li>ข้อมูลบัญชีผู้ใช้ (อีเมล รหัสผ่านแบบเข้ารหัส)</li>
</ul>
<p><strong>ข้อมูลที่เก็บโดยอัตโนมัติ:</strong></p>
<ul>
  <li>IP Address, ประเภทอุปกรณ์, เบราว์เซอร์</li>
  <li>หน้าที่เข้าชม, ระยะเวลาใช้งาน, แหล่งที่มา</li>
  <li>Cookies และ Local Storage สำหรับการตั้งค่าผู้ใช้</li>
</ul>
<h3>2. วัตถุประสงค์และฐานทางกฎหมายในการประมวลผล</h3>
<ul>
  <li><strong>การปฏิบัติตามสัญญา:</strong> ให้บริการตามที่ร้องขอ ติดต่อกลับเพื่อประสานงานซื้อ-ขาย-เช่า</li>
  <li><strong>ประโยชน์โดยชอบด้วยกฎหมาย:</strong> วิเคราะห์พฤติกรรมเพื่อพัฒนาบริการ ป้องกันการทุจริต</li>
  <li><strong>ความยินยอม:</strong> ส่งข่าวสาร โปรโมชั่น บทความอสังหาริมทรัพย์ (ถอนได้ตลอดเวลา)</li>
  <li><strong>การปฏิบัติตามกฎหมาย:</strong> บันทึกสำหรับกรมสรรพากร สำนักงานที่ดิน หากจำเป็น</li>
</ul>
<h3>3. ระยะเวลาการเก็บข้อมูล</h3>
<ul>
  <li>ข้อมูลบัญชีผู้ใช้: ตลอดอายุบัญชี + 90 วันหลังลบบัญชี</li>
  <li>ข้อมูลธุรกรรม: <strong>10 ปี</strong> ตามกฎหมายภาษีอากร</li>
  <li>ข้อมูลการติดต่อ (ฝากทรัพย์/ฝากความต้องการ): <strong>3 ปี</strong> หรือจนเสร็จสิ้นธุรกรรม</li>
  <li>Log การใช้งาน: <strong>12 เดือน</strong></li>
  <li>Cookies: ตามประเภท (Session / 1 ปี)</li>
</ul>
<h3>4. การเปิดเผยและโอนข้อมูล</h3>
<ul>
  <li><strong>ตัวแทนในเครือ Matchdoor:</strong> เฉพาะที่จำเป็นสำหรับให้บริการ</li>
  <li><strong>ผู้ให้บริการระบบ:</strong> Supabase (cloud database), Google Analytics (ถ้าได้รับความยินยอม)</li>
  <li><strong>หน่วยงานราชการ:</strong> เมื่อได้รับหมายศาล หรือตามที่กฎหมายกำหนด</li>
</ul>
<p><strong>เราไม่ขายข้อมูลส่วนบุคคลให้บุคคลที่สามโดยเด็ดขาด</strong></p>
<h3>5. ความปลอดภัยของข้อมูล</h3>
<ul>
  <li>เข้ารหัสข้อมูลด้วย TLS 1.3 ระหว่างการส่งผ่าน</li>
  <li>เก็บข้อมูลบน Supabase ที่ผ่านมาตรฐาน SOC 2 Type II</li>
  <li>รหัสผ่านถูก Hash ด้วย bcrypt ไม่มีการเก็บแบบ plaintext</li>
  <li>Row Level Security (RLS) บน Database ทุกตาราง</li>
</ul>
<h3>6. สิทธิ์ของเจ้าของข้อมูลส่วนบุคคล (PDPA มาตรา 30–43)</h3>
<ul>
  <li><strong>สิทธิ์ได้รับแจ้ง:</strong> รับทราบวัตถุประสงค์การเก็บรวบรวมข้อมูล</li>
  <li><strong>สิทธิ์เข้าถึง:</strong> ขอรับสำเนาข้อมูลส่วนบุคคลของตน</li>
  <li><strong>สิทธิ์แก้ไข:</strong> ขอแก้ไขข้อมูลที่ไม่ถูกต้อง</li>
  <li><strong>สิทธิ์ลบ:</strong> ขอให้ลบข้อมูลเมื่อไม่มีความจำเป็น</li>
  <li><strong>สิทธิ์คัดค้าน:</strong> คัดค้านการประมวลผลในบางกรณี</li>
  <li><strong>สิทธิ์โอนย้ายข้อมูล (Data Portability):</strong> ขอรับข้อมูลในรูปแบบที่อ่านได้ด้วยเครื่อง</li>
  <li><strong>สิทธิ์ถอนความยินยอม:</strong> ถอนได้ตลอดเวลา โดยไม่กระทบการประมวลผลก่อนหน้า</li>
</ul>
<p>ยื่นคำร้องได้ที่ <strong>privacy@matchdoor.co.th</strong> ตอบภายใน 30 วัน</p>
<h3>7. การเปลี่ยนแปลงนโยบาย</h3>
<p>เราจะแจ้งผ่านอีเมลหรือแบนเนอร์บนเว็บไซต์ล่วงหน้า 30 วันก่อนนโยบายใหม่มีผล</p>
<div class="highlight-box">
  <strong>📞 เจ้าหน้าที่คุ้มครองข้อมูล (DPO):</strong> privacy@matchdoor.co.th<br>
  <strong>📞 โทร:</strong> 061-589-xxxx (จ–ศ 09:00–18:00 น.)<br>
  <strong>📍 ที่อยู่:</strong> 123 ถนนสุขุมวิท แขวงคลองเตย กรุงเทพฯ 10110<br>
  <strong>🏛️ ร้องเรียน PDPA:</strong> สำนักงานคณะกรรมการคุ้มครองข้อมูลส่วนบุคคล (สคส.)
</div>
<p style="font-size:11px;margin-top:12px;opacity:.6">อัปเดตล่าสุด: มกราคม 2568 | อ้างอิง: พ.ร.บ.คุ้มครองข้อมูลส่วนบุคคล พ.ศ. 2562 (PDPA)</p>',
'1.0', '1 มกราคม 2568'),

('terms',
 'ข้อตกลงและเงื่อนไขการใช้งาน (Terms of Service)',
 '<div class="highlight-box" style="margin-bottom:16px">
  <strong>โปรดอ่านอย่างละเอียด:</strong> การใช้งานเว็บไซต์ Matchdoor ถือว่าคุณได้อ่านและยอมรับข้อตกลงฉบับนี้ทั้งหมดแล้ว
</div>
<h3>1. คำจำกัดความ</h3>
<ul>
  <li><strong>"Matchdoor"</strong> หมายถึง บริษัท แมตช์ดอร์ จำกัด และเว็บไซต์ matchdoor.co.th</li>
  <li><strong>"ผู้ใช้"</strong> หมายถึง บุคคลทุกคนที่เข้าใช้งานแพลตฟอร์ม</li>
  <li><strong>"ทรัพย์"</strong> หมายถึง อสังหาริมทรัพย์ทุกประเภทที่ลงในระบบ</li>
  <li><strong>"ตัวแทน"</strong> หมายถึง บุคคลที่ได้รับมอบอำนาจอย่างเป็นทางการจาก Matchdoor</li>
</ul>
<h3>2. การลงทะเบียนและบัญชีผู้ใช้</h3>
<ul>
  <li>ผู้ใช้ต้องมีอายุ <strong>18 ปีบริบูรณ์</strong> หรือมีผู้ปกครองยินยอม</li>
  <li>ต้องให้ข้อมูลที่ถูกต้อง ครบถ้วน และเป็นปัจจุบัน</li>
  <li>รับผิดชอบต่อกิจกรรมทั้งหมดที่เกิดขึ้นภายใต้บัญชีของตน</li>
  <li>ห้ามโอนบัญชีให้ผู้อื่นโดยไม่ได้รับอนุญาตจาก Matchdoor</li>
  <li>แจ้งทันทีหากสงสัยว่าบัญชีถูกเข้าถึงโดยไม่ได้รับอนุญาต</li>
</ul>
<h3>3. บริการของ Matchdoor</h3>
<ul>
  <li>แพลตฟอร์มประกาศและค้นหาอสังหาริมทรัพย์ออนไลน์</li>
  <li>บริการจับคู่ผู้ซื้อ ผู้ขาย และผู้เช่า</li>
  <li>บริการตัวแทนอสังหาริมทรัพย์มืออาชีพ</li>
  <li>บริการบ้านซ่อมและดูแลที่พักอาศัย</li>
  <li>เนื้อหาบทความ ข่าวสาร และข้อมูลตลาดอสังหาฯ</li>
</ul>
<h3>4. การลงประกาศทรัพย์</h3>
<ul>
  <li>ผู้ลงประกาศรับรองว่าตนมีสิทธิ์ในการขาย/เช่า/โอนทรัพย์ที่ลงประกาศ</li>
  <li>ข้อมูลที่ให้ต้องถูกต้อง ครบถ้วน ไม่หลอกลวง</li>
  <li>ประกาศมีอายุ 90 วัน จากนั้นต้องต่ออายุหรือประกาศใหม่</li>
  <li>ห้ามลงประกาศซ้ำซ้อนสำหรับทรัพย์เดียวกัน</li>
</ul>
<h3>5. ทรัพย์สินทางปัญญา</h3>
<ul>
  <li>เนื้อหา ภาพ โลโก้ โค้ด และซอฟต์แวร์บน Matchdoor เป็นกรรมสิทธิ์ของ Matchdoor</li>
  <li>ห้ามคัดลอก ดัดแปลง เผยแพร่โดยไม่ได้รับอนุญาต</li>
  <li>ผู้ลงประกาศยังคงเป็นเจ้าของลิขสิทธิ์รูปภาพของตน แต่อนุญาตให้ Matchdoor แสดงผลได้</li>
</ul>
<h3>6. การระงับและยกเลิกบัญชี</h3>
<p>Matchdoor สงวนสิทธิ์ระงับหรือยกเลิกบัญชีในกรณีดังนี้:</p>
<ul>
  <li>ละเมิดข้อตกลงหรือนโยบายการใช้งานที่ยอมรับได้</li>
  <li>ให้ข้อมูลเท็จหรือหลอกลวง</li>
  <li>ไม่ได้ใช้งานเกิน 2 ปี</li>
  <li>คำสั่งศาลหรือหน่วยงานกำกับดูแล</li>
</ul>
<h3>7. ข้อจำกัดความรับผิด</h3>
<ul>
  <li>Matchdoor ไม่รับประกันความต่อเนื่อง ความถูกต้อง หรือความพร้อมของบริการ</li>
  <li>ไม่รับผิดชอบต่อความเสียหายทางอ้อม ค่าเสียโอกาส หรือกำไรที่สูญเสีย</li>
  <li>ความรับผิดสูงสุดของ Matchdoor ไม่เกินค่าธรรมเนียมที่ได้รับในช่วง 3 เดือนก่อนหน้า</li>
</ul>
<h3>8. กฎหมายที่ใช้บังคับและการระงับข้อพิพาท</h3>
<ul>
  <li>ข้อตกลงนี้อยู่ภายใต้กฎหมายไทย</li>
  <li>ข้อพิพาทให้เจรจาก่อน หากตกลงกันไม่ได้ให้ใช้การไกล่เกลี่ย</li>
  <li>หากไกล่เกลี่ยไม่สำเร็จ ให้นำไปสู่ศาลที่มีเขตอำนาจในกรุงเทพมหานคร</li>
</ul>
<h3>9. การแก้ไขข้อตกลง</h3>
<p>Matchdoor อาจแก้ไขข้อตกลงนี้โดยแจ้งล่วงหน้า <strong>30 วัน</strong> ผ่านอีเมลหรือประกาศบนเว็บไซต์</p>
<div class="highlight-box">
  <strong>📧 ฝ่ายกฎหมาย:</strong> legal@matchdoor.co.th<br>
  <strong>📞 โทร:</strong> 061-589-xxxx<br>
  <strong>📍 ที่อยู่:</strong> 123 ถนนสุขุมวิท แขวงคลองเตย กรุงเทพฯ 10110
</div>
<p style="font-size:11px;margin-top:12px;opacity:.6">อัปเดตล่าสุด: มกราคม 2568 | อ้างอิง: ป.พ.พ., พ.ร.บ.คุ้มครองผู้บริโภค พ.ศ. 2522</p>',
'1.0', '1 มกราคม 2568'),

('acceptable_use',
 'นโยบายการใช้งานที่ยอมรับได้ (Acceptable Use Policy)',
 '<div class="highlight-box" style="margin-bottom:16px">
  <strong>มีผลบังคับใช้ตั้งแต่:</strong> 1 มกราคม 2568 | <strong>เวอร์ชัน:</strong> 1.0
</div>
<h3>1. วัตถุประสงค์</h3>
<p>นโยบายนี้กำหนดการใช้งานที่ยอมรับได้ของแพลตฟอร์ม Matchdoor เพื่อให้ผู้ใช้ทุกคนได้รับประสบการณ์ที่ปลอดภัย น่าเชื่อถือ และเป็นประโยชน์</p>
<h3>2. การใช้งานที่ได้รับอนุญาต</h3>
<ul>
  <li>ลงประกาศซื้อ ขาย เช่า อสังหาริมทรัพย์ที่ตนมีสิทธิ์โดยชอบธรรม</li>
  <li>ค้นหาและติดต่อสอบถามข้อมูลอสังหาริมทรัพย์เพื่อวัตถุประสงค์ส่วนตัวหรือธุรกิจ</li>
  <li>ใช้บริการค้นหา กรอง และเปรียบเทียบทรัพย์สิน</li>
  <li>ติดต่อตัวแทนอสังหาริมทรัพย์ที่ลงทะเบียนกับ Matchdoor</li>
  <li>อ่านและแชร์บทความ/เนื้อหาบนแพลตฟอร์มเพื่อจุดประสงค์ที่ไม่ใช่เชิงพาณิชย์</li>
</ul>
<h3>3. การใช้งานที่ไม่ได้รับอนุญาต</h3>
<ul>
  <li><strong>ข้อมูลเท็จ:</strong> ลงประกาศทรัพย์สินที่ไม่มีอยู่จริง หรือให้ข้อมูลเท็จ</li>
  <li><strong>การฉ้อโกง:</strong> ใช้แพลตฟอร์มเพื่อหลอกลวง ฟอกเงิน หรือกระทำการผิดกฎหมาย</li>
  <li><strong>Spam:</strong> ส่งข้อความโฆษณาจำนวนมาก หรือใช้ระบบในทางที่ผิด</li>
  <li><strong>Scraping:</strong> ดึงข้อมูลจากแพลตฟอร์มโดยอัตโนมัติโดยไม่ได้รับอนุญาต</li>
  <li><strong>การละเมิดลิขสิทธิ์:</strong> ใช้ภาพ เนื้อหา หรือข้อมูลของผู้อื่นโดยไม่ได้รับอนุญาต</li>
  <li><strong>การล่วงละเมิด:</strong> คุกคาม ข่มขู่ หรือทำให้ผู้ใช้รายอื่นรู้สึกไม่ปลอดภัย</li>
  <li><strong>Multi-account:</strong> สร้างบัญชีหลายบัญชีเพื่อหลีกเลี่ยงการระงับบัญชี</li>
  <li><strong>Malware:</strong> อัปโหลดไฟล์หรือลิงก์ที่มีโปรแกรมที่เป็นอันตราย</li>
</ul>
<h3>4. ประกาศอสังหาริมทรัพย์</h3>
<ul>
  <li>ต้องเป็นเจ้าของทรัพย์ หรือมีอำนาจในการขาย/เช่าโดยชอบธรรม</li>
  <li>รูปภาพต้องเป็นรูปจริงของทรัพย์สิน ไม่ใช่ภาพจาก stock photo หรือภาพของทรัพย์อื่น</li>
  <li>ราคาที่ระบุต้องเป็นราคาที่ตั้งใจขาย/เช่าจริง</li>
</ul>
<h3>5. ผลที่ตามมาหากละเมิด</h3>
<ul>
  <li>ลบประกาศหรือเนื้อหาที่ละเมิดโดยทันที</li>
  <li>ระงับการใช้งานชั่วคราวหรือถาวร</li>
  <li>รายงานต่อหน่วยงานกฎหมายที่เกี่ยวข้องหากเป็นการกระทำผิดกฎหมาย</li>
  <li>เรียกร้องค่าเสียหายตามกฎหมายหากเกิดความเสียหาย</li>
</ul>
<h3>6. การรายงานการละเมิด</h3>
<p>หากพบการใช้งานที่ไม่เหมาะสม กรุณาแจ้งได้ที่ <strong>report@matchdoor.co.th</strong> ทีมงานจะตรวจสอบภายใน 24 ชั่วโมง</p>
<div class="highlight-box">
  <strong>📧 ติดต่อฝ่ายกฎหมาย:</strong> legal@matchdoor.co.th<br>
  <strong>🚨 รายงานการละเมิด:</strong> report@matchdoor.co.th<br>
  <strong>⏱️ เวลาตอบสนอง:</strong> ภายใน 24–48 ชั่วโมงในวันทำการ
</div>
<p style="font-size:11px;margin-top:12px;opacity:.6">อัปเดตล่าสุด: มกราคม 2568 | สงวนลิขสิทธิ์ © 2568 Matchdoor</p>',
'1.0', '1 มกราคม 2568'),

('buy_sell',
 'เงื่อนไขการซื้อ-ขายและใช้งานเว็บไซต์',
 '<div class="highlight-box" style="margin-bottom:16px">
  <strong>สำคัญ:</strong> กรุณาอ่านเงื่อนไขนี้อย่างละเอียดก่อนทำธุรกรรมบนแพลตฟอร์ม Matchdoor
</div>
<h3>1. บทบาทของ Matchdoor</h3>
<p>Matchdoor ทำหน้าที่เป็น <strong>ตัวกลางแพลตฟอร์ม</strong> ในการเชื่อมต่อผู้ซื้อ ผู้ขาย และผู้เช่าเท่านั้น มิได้เป็นคู่สัญญาในการซื้อขายหรือเช่าอสังหาริมทรัพย์ใด ๆ โดยตรง</p>
<h3>2. ค่าธรรมเนียมและค่านายหน้า</h3>
<ul>
  <li><strong>ผู้ซื้อ/ผู้เช่า:</strong> ไม่มีค่าธรรมเนียมในการใช้งานแพลตฟอร์ม</li>
  <li><strong>ผู้ขาย/เจ้าของทรัพย์:</strong> ค่านายหน้ามาตรฐาน 2–3% ของราคาขาย (ตกลงกันก่อนเริ่มดำเนินการ)</li>
  <li><strong>ค่าเช่า:</strong> ค่านายหน้า 1 เดือนของค่าเช่ารายเดือน</li>
  <li>ค่าธรรมเนียมทั้งหมดจะแจ้งล่วงหน้าและต้องได้รับการยืนยันจากทั้งสองฝ่ายก่อนดำเนินการ</li>
</ul>
<h3>3. กระบวนการซื้อขาย</h3>
<ul>
  <li><strong>ขั้นตอนที่ 1:</strong> ผู้ซื้อ/ผู้เช่าติดต่อผ่านแพลตฟอร์มหรือตัวแทน</li>
  <li><strong>ขั้นตอนที่ 2:</strong> นัดชมทรัพย์พร้อมตัวแทน Matchdoor</li>
  <li><strong>ขั้นตอนที่ 3:</strong> ตกลงราคาและเงื่อนไข จัดทำบันทึกข้อตกลง (MOU)</li>
  <li><strong>ขั้นตอนที่ 4:</strong> ชำระเงินมัดจำตามที่ตกลง (ปกติ 1–5% ของราคาขาย)</li>
  <li><strong>ขั้นตอนที่ 5:</strong> ตรวจสอบเอกสารกรรมสิทธิ์ สัญญา และภาระผูกพัน</li>
  <li><strong>ขั้นตอนที่ 6:</strong> โอนกรรมสิทธิ์ที่สำนักงานที่ดิน</li>
</ul>
<h3>4. เงื่อนไขเงินมัดจำ</h3>
<ul>
  <li>เงินมัดจำถือเป็นส่วนหนึ่งของราคาซื้อขาย ไม่ใช่ค่าธรรมเนียม</li>
  <li>หากผู้ซื้อ<strong>ยกเลิก</strong>โดยไม่มีเหตุผลอันสมควร: ผู้ขายมีสิทธิ์ริบมัดจำ</li>
  <li>หากผู้ขาย<strong>ยกเลิก</strong>โดยไม่มีเหตุผลอันสมควร: ผู้ขายต้องคืนมัดจำ 2 เท่า</li>
</ul>
<h3>5. การตรวจสอบทรัพย์สิน</h3>
<p>Matchdoor แนะนำให้ผู้ซื้อ/ผู้เช่าดำเนินการดังนี้ก่อนทำสัญญา:</p>
<ul>
  <li>ตรวจสอบโฉนดที่ดิน/หนังสือกรรมสิทธิ์ที่กรมที่ดิน</li>
  <li>ตรวจสอบภาระหนี้จำนอง หรือภาระผูกพันบนทรัพย์</li>
  <li>ตรวจสอบสภาพทรัพย์โดยผู้เชี่ยวชาญ (Home Inspector)</li>
  <li>ตรวจสอบประวัติการชำระค่าส่วนกลาง/ค่าสาธารณูปโภค</li>
</ul>
<h3>6. ภาษีและค่าใช้จ่ายอื่น ๆ</h3>
<ul>
  <li><strong>ภาษีธุรกิจเฉพาะ:</strong> 3.3% (กรณีขายก่อน 5 ปี) ผู้ขายเป็นผู้รับผิดชอบ</li>
  <li><strong>ค่าอากรแสตมป์:</strong> 0.5% ของราคาขายหรือราคาประเมิน</li>
  <li><strong>ค่าโอนกรรมสิทธิ์:</strong> 2% ของราคาประเมิน (แบ่งจ่ายตามตกลง)</li>
  <li><strong>ภาษีเงินได้บุคคลธรรมดา:</strong> คำนวณตามอัตราก้าวหน้า ผู้ขายเป็นผู้รับผิดชอบ</li>
</ul>
<h3>7. ข้อจำกัดความรับผิดชอบ</h3>
<ul>
  <li>Matchdoor ไม่รับประกันความถูกต้องสมบูรณ์ของข้อมูลที่ผู้ลงประกาศเป็นผู้ให้</li>
  <li>ผู้ใช้รับทราบและยอมรับว่าการตัดสินใจซื้อ/ขาย/เช่า เป็นดุลพินิจส่วนตัว</li>
</ul>
<div class="highlight-box">
  <strong>📞 ฝ่ายกฎหมายและสัญญา:</strong> legal@matchdoor.co.th<br>
  <strong>📞 ฝ่ายบริการลูกค้า:</strong> 061-589-xxxx (จ–ศ 09:00–18:00 น.)<br>
  <strong>📍 สำนักงาน:</strong> 123 ถนนสุขุมวิท แขวงคลองเตย กรุงเทพฯ 10110
</div>
<p style="font-size:11px;margin-top:12px;opacity:.6">อัปเดตล่าสุด: มกราคม 2568 | อ้างอิง: ป.พ.พ. มาตรา 456–468, พ.ร.บ.นายหน้าอสังหาริมทรัพย์ พ.ศ.2545</p>',
'1.0', '1 มกราคม 2568'),

('cookie',
 'นโยบายการใช้คุกกี้ (Cookie Policy)',
 '<div class="highlight-box" style="margin-bottom:16px">
  <strong>มีผลบังคับ:</strong> 1 มกราคม 2568 | อ้างอิง: PDPA พ.ศ. 2562 และ ePrivacy Directive
</div>
<h3>1. คุกกี้คืออะไร?</h3>
<p>คุกกี้ (Cookie) คือไฟล์ข้อมูลขนาดเล็กที่บันทึกบนอุปกรณ์ของคุณเมื่อเข้าชมเว็บไซต์ ช่วยให้เว็บไซต์จดจำการตั้งค่าและพฤติกรรมการใช้งานของคุณ</p>
<h3>2. ประเภทคุกกี้ที่เราใช้</h3>
<ul>
  <li><strong>Necessary Cookies (จำเป็น):</strong> สำหรับการทำงานพื้นฐาน เช่น การ login ไม่สามารถปฏิเสธได้</li>
  <li><strong>Analytics Cookies (วิเคราะห์):</strong> Google Analytics วิเคราะห์การเข้าชม ต้องได้รับความยินยอม</li>
  <li><strong>Preference Cookies (การตั้งค่า):</strong> จดจำภาษา การค้นหาที่ผ่านมา ต้องได้รับความยินยอม</li>
  <li><strong>Marketing Cookies (การตลาด):</strong> โฆษณาที่ตรงกับความสนใจ ต้องได้รับความยินยอม</li>
</ul>
<h3>3. รายละเอียดคุกกี้ที่ใช้</h3>
<ul>
  <li><code>md_cookie_consent</code> — บันทึกการยอมรับ/ปฏิเสธคุกกี้ (localStorage, 1 ปี)</li>
  <li><code>md_favs</code> — บันทึกรายการโปรด (localStorage, ตลอดชีพ)</li>
  <li><code>sb-*</code> — Supabase Auth Session (Session, 1 ชั่วโมง)</li>
  <li><code>_ga</code> — Google Analytics (ถ้ายินยอม, 2 ปี)</li>
</ul>
<h3>4. การจัดการคุกกี้</h3>
<p>คุณสามารถควบคุมคุกกี้ได้โดย:</p>
<ul>
  <li>คลิก "ปฏิเสธที่ไม่จำเป็น" บน Banner คุกกี้</li>
  <li>ตั้งค่าเบราว์เซอร์ให้บล็อกคุกกี้ (อาจกระทบการทำงานบางส่วน)</li>
  <li>ล้าง localStorage ผ่าน Developer Tools ของเบราว์เซอร์</li>
</ul>
<h3>5. ผู้ให้บริการภายนอก</h3>
<ul>
  <li><strong>Supabase (US):</strong> ระบบฐานข้อมูลและ Authentication — มาตรฐาน SOC 2</li>
  <li><strong>Google Analytics (US):</strong> วิเคราะห์การเข้าชม — รับรอง GDPR (ถ้ายินยอม)</li>
  <li><strong>Google Maps:</strong> แสดงแผนที่ตำแหน่งทรัพย์</li>
</ul>
<h3>6. การเปลี่ยนแปลงนโยบาย</h3>
<p>เราจะแจ้งล่วงหน้า 30 วันก่อนนโยบายใหม่มีผล ผ่านอีเมลหรือแบนเนอร์บนเว็บไซต์</p>
<div class="highlight-box">
  <strong>📧 ติดต่อ DPO:</strong> privacy@matchdoor.co.th<br>
  <strong>📞 โทร:</strong> 061-589-xxxx (จ–ศ 09:00–18:00 น.)
</div>
<p style="font-size:11px;margin-top:12px;opacity:.6">อัปเดตล่าสุด: มกราคม 2568</p>',
'1.0', '1 มกราคม 2568')

ON CONFLICT (id) DO UPDATE SET
  title          = EXCLUDED.title,
  content        = EXCLUDED.content,
  version        = EXCLUDED.version,
  effective_date = EXCLUDED.effective_date,
  updated_at     = NOW();

-- ============================================================
-- 30. SEED DATA — properties เพิ่มเติม (30 รายการ)
--     ครบทุกหมวด: BTS ทุกสถานี, MRT ทุกสถานี,
--     มหาวิทยาลัยยอดนิยมทุกแห่งในกรุงเทพ,
--     ทำเลยอดนิยมทุกย่าน
-- ============================================================
INSERT INTO properties
  (id, title, type, province, location, price, tx, bed, bath, area,
   is_new, is_rec, description, agent_id, photos, created_at)
VALUES

-- ===== กลุ่ม BTS สุขุมวิท =====
('p21','คอนโดหรู ใกล้ BTS อโศก ชั้น 22 วิวเมือง',
 'คอนโด','กรุงเทพฯ','อโศก สุขุมวิท BTS อโศก MRT สุขุมวิท',
 6800000,'BUY',2,2,60,TRUE,TRUE,
 'คอนโดหรู 2 ห้องนอน ชั้น 22 วิวเมืองสวยงาม ห่าง BTS อโศก 150 เมตร เฟอร์นิเจอร์ Built-in ทั้งหลัง สระว่ายน้ำชั้นดาดฟ้า ฟิตเนส',
 'a5',
 ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
       'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
       'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800'],
 '2025-07-01'),

('p22','คอนโด BTS สยาม ใกล้ห้างพารากอน',
 'คอนโด','กรุงเทพฯ','สยาม ปทุมวัน BTS สยาม ใกล้ห้างสยามพารากอน',
 42000,'RENT',2,1,55,FALSE,TRUE,
 'คอนโดพรีเมียม ใกล้ห้างสยามพารากอน เดิน 3 นาทีถึง BTS สยาม เฟอร์นิเจอร์ครบ แอร์ทุกห้อง วิวสวน',
 'a8',
 ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800',
       'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'],
 '2025-07-05'),

('p23','คอนโด BTS ชิดลม ย่านเพลินจิต',
 'คอนโด','กรุงเทพฯ','ชิดลม เพลินจิต วิทยุ BTS ชิดลม',
 55000,'RENT',2,2,75,TRUE,TRUE,
 'คอนโดหรู CBD ย่านเพลินจิต ใกล้สถานทูต ห้างสรรพสินค้า ตกแต่งระดับ 5 ดาว ชั้น 28',
 'a5',
 ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
       'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800'],
 '2025-07-12'),

('p24','คอนโด BTS พร้อมพงษ์ เดินถึงห้างเอ็มโพเรียม',
 'คอนโด','กรุงเทพฯ','พร้อมพงษ์ คลองเตย BTS พร้อมพงษ์ ใกล้ห้างเอ็มโพเรียม',
 38000,'RENT',2,1,50,TRUE,TRUE,
 'คอนโดโมเดิร์น ใกล้ BTS พร้อมพงษ์ ห้างเอ็มโพเรียม เฟอร์นิเจอร์ครบชุด ชั้น 18 วิวสวย',
 'a8',
 ARRAY['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800',
       'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],
 '2025-07-03'),

('p25','คอนโด BTS เอกมัย ห้องมุมวิวเมือง',
 'คอนโด','กรุงเทพฯ','เอกมัย วัฒนา BTS เอกมัย',
 4800000,'BUY',2,1,52,FALSE,TRUE,
 'คอนโดห้องมุม 2 ห้องนอน ใกล้ BTS เอกมัย ย่านไลฟ์สไตล์ ร้านอาหาร คาเฟ่ ตลาดนัด',
 'a7',
 ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
       'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800'],
 '2025-06-28'),

('p26','คอนโด BTS อ่อนนุช ราคาน่าสนใจ',
 'คอนโด','กรุงเทพฯ','อ่อนนุช สุขุมวิท BTS อ่อนนุช',
 3100000,'BUY',1,1,33,TRUE,FALSE,
 'คอนโดใกล้ BTS อ่อนนุช เดิน 5 นาที ห้องตกแต่งใหม่ สวนน้ำ ฟิตเนส ที่จอดรถ',
 'a13',
 ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
 '2025-07-08'),

('p27','คอนโด BTS บางนา ใกล้ Mega Bangna',
 'คอนโด','กรุงเทพฯ','บางนา สาทร BTS บางนา ใกล้ Mega Bangna',
 2900000,'BUY',1,1,35,TRUE,FALSE,
 'คอนโดพร้อมอยู่ ใกล้ BTS บางนา ห้าง Mega Bangna เส้นทางสะดวก ใกล้ทางด่วน',
 'a17',
 ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
 '2025-07-06'),

('p28','คอนโดให้เช่า BTS สะพานควาย ห้องใหม่',
 'คอนโด','กรุงเทพฯ','สะพานควาย พหลโยธิน BTS สะพานควาย',
 18000,'RENT',1,1,38,TRUE,FALSE,
 'คอนโดใหม่ ใกล้ BTS สะพานควาย ย่านกินดื่ม ร้านอาหารหลากหลาย เฟอร์นิเจอร์ครบ',
 'a19',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-07-10'),

('p29','คอนโด BTS อารีย์ ย่านคาเฟ่ฮิต',
 'คอนโด','กรุงเทพฯ','อารีย์ พหลโยธิน BTS อารีย์',
 5200000,'BUY',2,1,48,FALSE,TRUE,
 'คอนโดทำเลยอดนิยม ย่านอารีย์ คาเฟ่ ร้านอาหาร ใกล้ BTS อารีย์ ชั้น 15 วิวสวน',
 'a3',
 ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800',
       'https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800'],
 '2025-07-04'),

('p30','บ้านเดี่ยว ใกล้ BTS หมอชิต',
 'บ้านเดี่ยว','กรุงเทพฯ','หมอชิต จตุจักร BTS หมอชิต MRT จตุจักร',
 9500000,'BUY',4,3,280,TRUE,TRUE,
 'บ้านเดี่ยวสไตล์โมเดิร์น ใกล้ BTS หมอชิต ตลาดนัดจตุจักร สวนรถไฟ ชานเมืองสีเขียว',
 'a6',
 ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800',
       'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800'],
 '2025-07-09'),

-- ===== กลุ่ม BTS สีลม =====
('p31','คอนโด BTS วงเวียนใหญ่ ทำเลเด่น',
 'คอนโด','กรุงเทพฯ','วงเวียนใหญ่ ธนบุรี BTS วงเวียนใหญ่',
 3500000,'BUY',1,1,40,TRUE,FALSE,
 'คอนโดทำเลใหม่ ย่านวงเวียนใหญ่ กำลังเติบโต ใกล้ BTS ชั้น 18 วิวแม่น้ำ',
 'a20',
 ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],
 '2025-06-30'),

('p32','คอนโด BTS กรุงธนบุรี วิวแม่น้ำ',
 'คอนโด','กรุงเทพฯ','กรุงธนบุรี คลองสาน BTS กรุงธนบุรี ใกล้ ICONSIAM',
 7800000,'BUY',2,2,65,TRUE,TRUE,
 'คอนโดหรู วิวแม่น้ำเจ้าพระยา ใกล้ ICONSIAM BTS กรุงธนบุรี ชั้น 30 ตกแต่งพร้อม',
 'a5',
 ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800',
       'https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800'],
 '2025-07-02'),

-- ===== กลุ่ม MRT สายสีน้ำเงิน =====
('p33','คอนโด MRT พระราม 9 ใกล้ห้าง Central',
 'คอนโด','กรุงเทพฯ','พระราม 9 ห้วยขวาง MRT พระราม 9 ใกล้ห้าง Central พระราม 9',
 4200000,'BUY',1,1,40,TRUE,TRUE,
 'คอนโด High Rise ใกล้ MRT พระราม 9 ห้าง Central พระราม 9 ตกแต่งพร้อมอยู่ ชั้น 25',
 'a7',
 ARRAY['https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
       'https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],
 '2025-06-20'),

('p34','คอนโดให้เช่า MRT สีลม ย่านธุรกิจ',
 'คอนโด','กรุงเทพฯ','สีลม บางรัก MRT สีลม BTS ช่องนนทรี',
 28000,'RENT',1,1,45,FALSE,TRUE,
 'คอนโด CBD ย่านธุรกิจ ห่าง MRT สีลม 200 เมตร ห้องมุม วิวสวน เฟอร์นิเจอร์พร้อม',
 'a2',
 ARRAY['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800',
       'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800'],
 '2025-06-18'),

('p35','คอนโด MRT สุทธิสาร ห้องมุมวิวสวน',
 'คอนโด','กรุงเทพฯ','สุทธิสาร ห้วยขวาง MRT สุทธิสาร',
 3900000,'BUY',2,1,48,FALSE,TRUE,
 'คอนโดห้องมุม ใกล้ MRT สุทธิสาร ย่านที่อยู่อาศัย สงบ วิวสวน ชั้น 15',
 'a3',
 ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],
 '2025-06-22'),

('p36','คอนโดให้เช่า MRT ห้วยขวาง สไตล์ญี่ปุ่น',
 'คอนโด','กรุงเทพฯ','ห้วยขวาง รัชดาภิเษก MRT ห้วยขวาง',
 16000,'RENT',1,1,35,TRUE,FALSE,
 'คอนโดใกล้ MRT ห้วยขวาง ตกแต่งสไตล์ญี่ปุ่น สะอาด ใกล้ตลาด ร้านอาหาร',
 'a20',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-07-07'),

('p37','คอนโดหรู MRT รัชดา ย่านกลางเมือง',
 'คอนโด','กรุงเทพฯ','รัชดาภิเษก ห้วยขวาง MRT รัชดา',
 5500000,'BUY',2,2,65,TRUE,TRUE,
 'คอนโดหรู ย่านรัชดาภิเษก ชั้น 30+ วิวโล่ง ใกล้ MRT รัชดา และ Central พระราม 9',
 'a3',
 ARRAY['https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800',
       'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800'],
 '2025-07-10'),

('p38','คอนโด MRT ลาดพร้าว ใกล้ห้างยูเนี่ยน',
 'คอนโด','กรุงเทพฯ','ลาดพร้าว บึงกุ่ม MRT ลาดพร้าว ใกล้ห้างยูเนี่ยน',
 4600000,'BUY',2,2,58,TRUE,TRUE,
 'คอนโดใกล้ MRT ลาดพร้าว ห้างยูเนี่ยน เจริญนคร เดินทางสะดวกทุกทิศทาง',
 'a13',
 ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800',
       'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
 '2025-07-06'),

('p39','ทาวน์โฮม ใกล้ MRT จตุจักร ตลาดนัดสวรรค์',
 'ทาวน์โฮม','กรุงเทพฯ','จตุจักร พหลโยธิน BTS หมอชิต MRT จตุจักร',
 8500000,'BUY',4,3,220,FALSE,TRUE,
 'ทาวน์โฮม Luxury ใกล้ MRT จตุจักร BTS หมอชิต ตลาดนัดจตุจักร พร้อมลิฟต์ภายใน',
 'a11',
 ARRAY['https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800',
       'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800'],
 '2025-06-25'),

-- ===== กลุ่มมหาวิทยาลัยยอดนิยมในกรุงเทพ =====
('p40','ห้องเช่า ใกล้ จุฬาลงกรณ์มหาวิทยาลัย สามย่าน',
 'คอนโด','กรุงเทพฯ','สามย่าน ปทุมวัน MRT สามย่าน ใกล้ จุฬาลงกรณ์มหาวิทยาลัย',
 14000,'RENT',1,1,32,FALSE,FALSE,
 'คอนโดสตูดิโอ ห่างจุฬาลงกรณ์มหาวิทยาลัย 500 เมตร เฟอร์นิเจอร์ครบ อินเตอร์เน็ต รปภ. 24 ชั่วโมง',
 'a19',
 ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
 '2025-06-01'),

('p41','คอนโดให้เช่า ใกล้ ม.เกษตรศาสตร์ บางเขน',
 'คอนโด','กรุงเทพฯ','เกษตร-นวมินทร์ ลาดยาว ใกล้ มหาวิทยาลัยเกษตรศาสตร์ บางเขน',
 8500,'RENT',1,1,28,TRUE,FALSE,
 'คอนโดสตูดิโอ ใกล้ ม.เกษตรบางเขน 300 เมตร ปลอดภัย ราคาประหยัด มีที่จอดจักรยาน',
 'a2',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-05-25'),

('p42','ทาวน์โฮมให้เช่า ใกล้ ม.ธรรมศาสตร์ รังสิต',
 'ทาวน์โฮม','ปทุมธานี','รังสิต คลองหลวง ใกล้ มหาวิทยาลัยธรรมศาสตร์ รังสิต',
 9500,'RENT',3,2,110,TRUE,FALSE,
 'ทาวน์โฮม 2 ชั้น ใกล้ ม.ธรรมศาสตร์รังสิต เดินทางง่าย จอดรถได้ 2 คัน',
 'a13',
 ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
 '2025-06-08'),

('p43','คอนโดให้เช่า ใกล้ มหาวิทยาลัยมหิดล ศาลายา',
 'คอนโด','นครปฐม','ศาลายา พุทธมณฑล ใกล้ มหาวิทยาลัยมหิดล ศาลายา',
 6500,'RENT',1,1,24,TRUE,FALSE,
 'ห้องพักใกล้ ม.มหิดล ศาลายา ราคาประหยัด อินเตอร์เน็ต ปลอดภัย ร้านอาหารเยอะ',
 'a12',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-06-05'),

('p44','คอนโดให้เช่า ใกล้ ม.รังสิต ปทุมธานี',
 'คอนโด','ปทุมธานี','คลองหลวง ธัญบุรี ใกล้ มหาวิทยาลัยรังสิต',
 7500,'RENT',1,1,26,FALSE,FALSE,
 'ห้องพักสะอาด ห่าง ม.รังสิต 400 เมตร ครัวรวม WiFi ฟรี ราคาประหยัด',
 'a13',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-05-28'),

('p45','ห้องเช่า ใกล้ ม.กรุงเทพ รังสิต',
 'คอนโด','ปทุมธานี','รังสิต ลำลูกกา ใกล้ มหาวิทยาลัยกรุงเทพ รังสิต',
 7000,'RENT',1,1,28,FALSE,FALSE,
 'คอนโดใกล้ ม.กรุงเทพ รังสิต ปลอดภัย เงียบสงบ มีนิติบุคคล',
 'a19',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-06-10'),

('p46','คอนโด ใกล้ ม.ศรีปทุม บางเขน',
 'คอนโด','กรุงเทพฯ','บางเขน พหลโยธิน ใกล้ มหาวิทยาลัยศรีปทุม บางเขน',
 9000,'RENT',1,1,30,TRUE,FALSE,
 'คอนโดใกล้ ม.ศรีปทุม บางเขน เดินทางสะดวก BTS สะพานควาย มีร้านอาหารรอบข้าง',
 'a17',
 ARRAY['https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2025-07-01'),

('p47','ทาวน์โฮม ใกล้ ม.นิด้า สะพานใหม่',
 'ทาวน์โฮม','กรุงเทพฯ','สะพานใหม่ ลาดพร้าว ใกล้ สถาบันบัณฑิตพัฒนบริหารศาสตร์ นิด้า',
 3800000,'BUY',3,2,140,FALSE,FALSE,
 'ทาวน์โฮม 2 ชั้น ใกล้ นิด้า สะพานใหม่ บึงกุ่ม เดินทางสะดวก',
 'a17',
 ARRAY['https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
 '2025-06-15'),

-- ===== ทำเลยอดนิยมเพิ่มเติม =====
('p48','บ้านเดี่ยวหรู สุขุมวิท 71 Penthouse',
 'บ้านเดี่ยว','กรุงเทพฯ','สุขุมวิท 71 พระโขนง ใกล้ BTS พระโขนง',
 35000000,'BUY',5,5,500,TRUE,TRUE,
 'บ้านเดี่ยว Luxury ทำเลสุขุมวิท 5 ห้องนอน 5 ห้องน้ำ สระว่ายน้ำ ห้อง Home Theater',
 'a4',
 ARRAY['https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800',
       'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800',
       'https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800'],
 '2025-07-02'),

('p49','คอนโดหรู ย่านสาทร วิวแม่น้ำ',
 'คอนโด','กรุงเทพฯ','สาทร ยานนาวา BTS ช่องนนทรี MRT สีลม ใกล้ย่านสาทร',
 12500000,'BUY',3,3,120,FALSE,TRUE,
 'คอนโด Super Luxury วิวแม่น้ำ 180 องศา ย่านสาทร ใกล้ BTS ช่องนนทรี ชั้น 40',
 'a4',
 ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800',
       'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],
 '2025-06-25'),

('p50','ที่ดินเปล่า ลาดพร้าว ทรงสี่เหลี่ยม ใกล้ MRT',
 'ที่ดิน','กรุงเทพฯ','ลาดพร้าว บึงกุ่ม MRT ลาดพร้าว ใกล้ MRT สายสีน้ำเงิน',
 8800000,'BUY',0,0,220,FALSE,TRUE,
 'ที่ดินเปล่าทรงสี่เหลี่ยม ย่านลาดพร้าว เหมาะสร้างบ้าน หน้ากว้าง 15 เมตร ใกล้ MRT',
 'a4',
 ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800'],
 '2025-05-15')

ON CONFLICT (id) DO UPDATE SET
  title       = EXCLUDED.title,
  type        = EXCLUDED.type,
  province    = EXCLUDED.province,
  location    = EXCLUDED.location,
  price       = EXCLUDED.price,
  tx          = EXCLUDED.tx,
  bed         = EXCLUDED.bed,
  bath        = EXCLUDED.bath,
  area        = EXCLUDED.area,
  is_new      = EXCLUDED.is_new,
  is_rec      = EXCLUDED.is_rec,
  description = EXCLUDED.description,
  agent_id    = EXCLUDED.agent_id,
  photos      = EXCLUDED.photos,
  updated_at  = NOW();

-- ============================================================
-- 31. อัปเดต site_config — เพิ่ม social media fields
--     HTML ใช้: fb_url, line_id, phone สำหรับ floating buttons
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='site_config' AND column_name='tel_url'
  ) THEN
    ALTER TABLE site_config ADD COLUMN tel_url TEXT;
    ALTER TABLE site_config ADD COLUMN line_url TEXT;
    ALTER TABLE site_config ADD COLUMN tiktok_url TEXT;
    ALTER TABLE site_config ADD COLUMN instagram_url TEXT;
  END IF;
END $$;

UPDATE site_config SET
  tel_url       = 'tel:061-589-xxxx',
  line_url      = 'https://line.me/ti/p/@matchdoor',
  tiktok_url    = NULL,
  instagram_url = NULL
WHERE id = 1;

-- ============================================================
-- 32. VIEW: v_quick_search_locations
--     ใช้สำหรับ Quick Search dropdown (ทำเล, BTS, MRT, มหาวิทยาลัย)
--     HTML ดึงจาก properties.location โดยตรง แต่ view นี้
--     ช่วย Admin เห็นภาพรวม keyword ที่มีทรัพย์จริง
-- ============================================================
DROP VIEW IF EXISTS v_quick_search_locations;
CREATE VIEW v_quick_search_locations AS
SELECT DISTINCT
  province,
  COUNT(*) AS property_count
FROM properties
GROUP BY province
ORDER BY property_count DESC;

-- ============================================================
-- 33. FUNCTION: search_properties_full
--     Full-text search ครบทุก field ที่ HTML ใช้
--     สนับสนุน keyword จาก Quick Search: BTS, MRT, มหาวิทยาลัย, ทำเล
-- ============================================================
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
-- 34. INDEX เพิ่มเติมสำหรับ description search
--     HTML filterProperties() ใช้ description.ilike ด้วย
-- ============================================================
DROP INDEX IF EXISTS idx_properties_desc_trgm;
CREATE INDEX idx_properties_desc_trgm
  ON properties USING gin (description gin_trgm_ops);

-- ============================================================
-- 35. FIX VIEW: v_agent_performance (แก้ placeholder join)
-- ============================================================
DROP VIEW IF EXISTS v_agent_performance;
CREATE VIEW v_agent_performance AS
SELECT
  a.id,
  a.name,
  a.title,
  a.phone,
  a.avatar_url,
  COUNT(DISTINCT p.id)  AS active_properties,
  COUNT(DISTINCT po.id) AS total_deals
FROM agents a
LEFT JOIN properties p  ON p.agent_id = a.id
LEFT JOIN portfolio  po ON TRUE  -- ให้ count portfolio ทั้งหมดเป็น baseline
WHERE a.is_active = TRUE
GROUP BY a.id, a.name, a.title, a.phone, a.avatar_url;

-- ============================================================
-- 36. TRIGGER: updated_at สำหรับ legal_pages
-- ============================================================
DO $$ BEGIN
  EXECUTE 'DROP TRIGGER IF EXISTS trg_updated_at_legal ON legal_pages;
    CREATE TRIGGER trg_updated_at_legal
    BEFORE UPDATE ON legal_pages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ============================================================
-- 37. STORAGE: เพิ่ม bucket สำหรับ blog images
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('blog-images', 'blog-images', TRUE)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "public_read_blog_images" ON storage.objects;
CREATE POLICY "public_read_blog_images" ON storage.objects
  FOR SELECT USING (bucket_id = 'blog-images');

DROP POLICY IF EXISTS "auth_upload_blog_images" ON storage.objects;
CREATE POLICY "auth_upload_blog_images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'blog-images' AND auth.role() = 'authenticated'
  );


-- ============================================================
-- 38. SEED DATA — legal_pages (5 หน้า แก้ไขได้ผ่าน Supabase Dashboard)
--     id ตรงกับ HTML: privacy | terms | acceptable_use | buy_sell | cookie
--     เนื้อหาเริ่มต้น — แอดมินสามารถแก้ไขใน Supabase Dashboard ได้เลย
-- ============================================================

INSERT INTO legal_pages (id, title, content, version, effective_date)
VALUES
('privacy',
 'นโยบายความเป็นส่วนตัว (Privacy Policy)',
 '<div class="highlight-box" style="margin-bottom:16px"><strong>บังคับใช้ตาม:</strong> พ.ร.บ.คุ้มครองข้อมูลส่วนบุคคล (PDPA) พ.ศ. 2562</div>
<h3>1. ข้อมูลที่เราเก็บรวบรวม</h3>
<p>ชื่อ-นามสกุล เบอร์โทรศัพท์ อีเมล Line ID รายละเอียดความต้องการอสังหาริมทรัพย์ และข้อมูลที่เก็บอัตโนมัติ เช่น IP Address, cookies</p>
<h3>2. วัตถุประสงค์การใช้ข้อมูล</h3>
<p>เพื่อให้บริการซื้อ-ขาย-เช่าอสังหาริมทรัพย์ ติดต่อกลับลูกค้า วิเคราะห์เพื่อพัฒนาบริการ และปฏิบัติตามกฎหมาย</p>
<h3>3. การเปิดเผยข้อมูล</h3>
<p>เราไม่ขายข้อมูลส่วนบุคคลของคุณ อาจแบ่งปันกับหน่วยงานกฎหมายเฉพาะเมื่อจำเป็น</p>
<h3>4. สิทธิ์ของท่าน</h3>
<p>ท่านมีสิทธิ์เข้าถึง แก้ไข ลบ หรือขอสำเนาข้อมูลส่วนบุคคลของตนเองได้ตลอดเวลา ติดต่อ: privacy@matchdoor.co.th</p>
<div class="highlight-box"><strong>📧 ติดต่อ DPO:</strong> privacy@matchdoor.co.th | <strong>📞 โทร:</strong> 061-589-xxxx</div>',
 '2.0', '2025-01-01'),

('terms',
 'ข้อกำหนดการใช้งาน (Terms of Service)',
 '<div class="highlight-box" style="margin-bottom:16px"><strong>กรุณาอ่านข้อกำหนดนี้ก่อนใช้งาน Matchdoor</strong></div>
<h3>1. การยอมรับข้อกำหนด</h3>
<p>การใช้งานแพลตฟอร์ม Matchdoor ถือว่าท่านยอมรับข้อกำหนดและเงื่อนไขทั้งหมดนี้</p>
<h3>2. บัญชีผู้ใช้</h3>
<p>ท่านต้องให้ข้อมูลที่ถูกต้องและรับผิดชอบต่อกิจกรรมทั้งหมดที่เกิดขึ้นภายใต้บัญชีของท่าน</p>
<h3>3. การใช้งานที่ยอมรับได้</h3>
<p>ห้ามโพสต์ข้อมูลเท็จ ฉ้อโกง หรือเนื้อหาที่ผิดกฎหมาย</p>
<h3>4. ทรัพย์สินทางปัญญา</h3>
<p>เนื้อหาบน Matchdoor เป็นลิขสิทธิ์ของบริษัท ห้ามนำไปใช้โดยไม่ได้รับอนุญาต</p>
<h3>5. การยกเลิกบัญชี</h3>
<p>เราขอสงวนสิทธิ์ยกเลิกบัญชีที่ละเมิดข้อกำหนดโดยไม่ต้องแจ้งล่วงหน้า</p>
<div class="highlight-box"><strong>📧 ติดต่อ:</strong> legal@matchdoor.co.th</div>',
 '2.0', '2025-01-01'),

('acceptable_use',
 'นโยบายการใช้งานที่ยอมรับได้ (Acceptable Use Policy)',
 '<div class="highlight-box" style="margin-bottom:16px"><strong>เพื่อให้ Matchdoor เป็นพื้นที่ที่ปลอดภัยสำหรับทุกคน</strong></div>
<h3>สิ่งที่ห้ามทำ</h3>
<ul>
  <li>โพสต์ประกาศเท็จหรือข้อมูลที่ทำให้เข้าใจผิด</li>
  <li>ฉ้อโกงหรือหลอกลวงผู้ใช้รายอื่น</li>
  <li>ส่ง spam หรือโฆษณาที่ไม่พึงประสงค์</li>
  <li>ใช้บอทหรือโปรแกรมอัตโนมัติโดยไม่ได้รับอนุญาต</li>
  <li>เผยแพร่ข้อมูลส่วนบุคคลของผู้อื่น</li>
</ul>
<h3>บทลงโทษ</h3>
<p>การละเมิดอาจส่งผลให้ถูกระงับหรือยกเลิกบัญชีถาวร และอาจดำเนินคดีตามกฎหมาย</p>
<div class="highlight-box"><strong>🚨 รายงานการละเมิด:</strong> report@matchdoor.co.th</div>',
 '1.0', '2025-01-01'),

('buy_sell',
 'เงื่อนไขการซื้อ-ขาย (Buy/Sell Terms)',
 '<div class="highlight-box" style="margin-bottom:16px"><strong>สำคัญ:</strong> กรุณาอ่านก่อนทำธุรกรรมบน Matchdoor</div>
<h3>1. บทบาทของ Matchdoor</h3>
<p>Matchdoor เป็นตัวกลางเชื่อมต่อผู้ซื้อ ผู้ขาย และผู้เช่าเท่านั้น ไม่ใช่คู่สัญญาโดยตรง</p>
<h3>2. ค่าธรรมเนียม</h3>
<ul>
  <li>ผู้ซื้อ/ผู้เช่า: ฟรี ไม่มีค่าใช้จ่าย</li>
  <li>ผู้ขาย: ค่านายหน้า 2–3% ของราคาขาย</li>
  <li>ให้เช่า: ค่านายหน้า 1 เดือนของค่าเช่า</li>
</ul>
<h3>3. กระบวนการซื้อขาย</h3>
<p>ติดต่อตัวแทน → นัดชมทรัพย์ → ตกลงราคา → ทำ MOU → วางมัดจำ → โอนกรรมสิทธิ์</p>
<h3>4. ข้อจำกัดความรับผิดชอบ</h3>
<p>Matchdoor ไม่รับประกันความถูกต้องของข้อมูลที่ผู้ลงประกาศให้ และไม่รับผิดชอบต่อข้อพิพาทระหว่างคู่กรณี</p>
<div class="highlight-box"><strong>📞 ฝ่ายกฎหมาย:</strong> legal@matchdoor.co.th | <strong>📞 บริการลูกค้า:</strong> 061-589-xxxx</div>',
 '2.0', '2025-01-01'),

('cookie',
 'นโยบายคุกกี้ (Cookie Policy)',
 '<div class="highlight-box" style="margin-bottom:16px">เว็บไซต์ของเราใช้คุกกี้เพื่อพัฒนาประสบการณ์การใช้งาน</div>
<h3>คุกกี้ที่จำเป็น (Necessary)</h3>
<p>จำเป็นสำหรับการทำงานพื้นฐานของเว็บไซต์ เช่น การล็อกอิน รายการโปรด ไม่สามารถปิดได้</p>
<h3>คุกกี้วิเคราะห์ (Analytics)</h3>
<p>ช่วยให้เราเข้าใจว่าผู้ใช้ใช้เว็บไซต์อย่างไร เพื่อนำไปพัฒนา ท่านสามารถปฏิเสธได้</p>
<h3>การจัดการคุกกี้</h3>
<p>ท่านสามารถตั้งค่าคุกกี้ได้ผ่านแบนเนอร์คุกกี้ที่ด้านล่างของหน้าจอ หรือในการตั้งค่าเบราว์เซอร์</p>
<div class="highlight-box"><strong>📧 ติดต่อ:</strong> privacy@matchdoor.co.th</div>',
 '1.0', '2025-01-01')

ON CONFLICT (id) DO UPDATE SET
  title          = EXCLUDED.title,
  content        = EXCLUDED.content,
  version        = EXCLUDED.version,
  effective_date = EXCLUDED.effective_date,
  updated_at     = NOW();

-- ============================================================
-- ✅ DONE — Matchdoor Database v5.0
-- ============================================================
-- เพิ่มจาก v4.1:
--   38. legal_pages seed data (5 หน้า แก้ไขได้ผ่าน Supabase Dashboard)
--       id: privacy | terms | acceptable_use | buy_sell | cookie
-- ============================================================
