-- ============================================================
-- MATCHDOOR — Supabase SQL Schema + Seed Data
-- Version : 10.0 — เพิ่ม properties เป็น 95 รายการ
-- Updated : 2026 (พฤษภาคม)
-- ============================================================
-- ✅ รองรับทุก query ใน index.html:
--    • properties, agents, portfolio, services, blogs
--    • listings (consent_given, consent_timestamp)
--    • buy_requests (consent_given, consent_timestamp)
--    • legal_pages, site_config, admin_users, favorites
--    • views: v_properties_with_agent, v_dashboard_summary
--    • function: search_properties_full()
--    • storage buckets + RLS policies
-- วิธีใช้: วางทั้งหมดใน Supabase SQL Editor แล้วกด Run
--          รันซ้ำได้ไม่ error (idempotent)
-- ============================================================

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- 1. ENUM TYPES
-- ============================================================
DO $$ BEGIN CREATE TYPE property_type_enum AS ENUM (
  'บ้านเดี่ยว','ทาวน์โฮม','คอนโด','ที่ดิน','อาคารพาณิชย์','วิลล่า','รีสอร์ท','โรงแรม'
); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN CREATE TYPE transaction_enum      AS ENUM ('BUY','RENT');                                   EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE listing_status_enum  AS ENUM ('รอตรวจสอบ','อนุมัติ','ปฏิเสธ','ปิด');           EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE request_status_enum  AS ENUM ('ใหม่','กำลังดำเนินการ','จับคู่แล้ว','ปิด');      EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE portfolio_status_enum AS ENUM ('SOLD','RENTED');                               EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 2. TABLES
-- ============================================================

-- agents
CREATE TABLE IF NOT EXISTS agents (
  id          TEXT         PRIMARY KEY,
  name        TEXT         NOT NULL,
  title       TEXT,
  phone       TEXT,
  line_id     TEXT,
  initials    TEXT,
  color       TEXT         DEFAULT '#7c6fcd',
  bio         TEXT,
  prop_ids    TEXT[]       DEFAULT '{}',
  is_active   BOOLEAN      DEFAULT TRUE,
  avatar_url  TEXT,
  photos      TEXT[]       DEFAULT '{}',
  rating      NUMERIC(3,2) DEFAULT 4.5,
  created_at  TIMESTAMPTZ  DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- properties
CREATE TABLE IF NOT EXISTS properties (
  id           TEXT              PRIMARY KEY,
  title        TEXT              NOT NULL,
  type         property_type_enum,
  province     TEXT,
  location     TEXT,
  price        NUMERIC(18,2)     NOT NULL DEFAULT 0,
  tx           transaction_enum  NOT NULL DEFAULT 'BUY',
  bed          INT               DEFAULT 0,
  bath         INT               DEFAULT 0,
  area         NUMERIC(12,2)     DEFAULT 0,
  land_area    NUMERIC(12,2)     DEFAULT 0,
  floors       INT               DEFAULT 0,
  floor_no     INT               DEFAULT 0,
  parking      INT               DEFAULT 0,
  furniture    TEXT              DEFAULT '',
  pets_allowed BOOLEAN           DEFAULT FALSE,
  appliances   TEXT[]            DEFAULT '{}',
  is_new       BOOLEAN           DEFAULT FALSE,
  is_rec       BOOLEAN           DEFAULT FALSE,
  description  TEXT,
  agent_id     TEXT              REFERENCES agents(id) ON DELETE SET NULL,
  photos       TEXT[]            DEFAULT '{}',
  created_at   TIMESTAMPTZ       DEFAULT NOW(),
  updated_at   TIMESTAMPTZ       DEFAULT NOW()
);

-- portfolio
CREATE TABLE IF NOT EXISTS portfolio (
  id         TEXT                  PRIMARY KEY,
  title      TEXT                  NOT NULL,
  type       property_type_enum,
  price      NUMERIC(18,2),
  status     portfolio_status_enum,
  location   TEXT,
  date       TEXT,
  review     TEXT,
  photo      TEXT,
  photos     TEXT[]                DEFAULT '{}',
  created_at TIMESTAMPTZ           DEFAULT NOW()
);

-- services
CREATE TABLE IF NOT EXISTS services (
  id         TEXT        PRIMARY KEY,
  name       TEXT        NOT NULL,
  icon       TEXT,
  short_desc TEXT,
  full_desc  TEXT,
  price      TEXT,
  duration   TEXT,
  line_id    TEXT,
  phone      TEXT,
  is_active  BOOLEAN     DEFAULT TRUE,
  sort_order INT         DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- blogs
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

-- listings (ฟอร์มฝากขาย/เช่า จาก index.html)
CREATE TABLE IF NOT EXISTS listings (
  id                UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID                REFERENCES auth.users(id) ON DELETE SET NULL,
  name              TEXT                NOT NULL,
  phone             TEXT                NOT NULL,
  property_type     TEXT,
  price             NUMERIC(18,2)       DEFAULT 0,
  province          TEXT,
  transaction       TEXT,
  details           TEXT,
  photos            TEXT[]              DEFAULT '{}',
  status            listing_status_enum DEFAULT 'รอตรวจสอบ',
  admin_note        TEXT,
  consent_given     BOOLEAN             DEFAULT FALSE,
  consent_timestamp TIMESTAMPTZ,
  created_at        TIMESTAMPTZ         DEFAULT NOW(),
  updated_at        TIMESTAMPTZ         DEFAULT NOW()
);

-- buy_requests (ฟอร์มแจ้งความต้องการซื้อ จาก index.html)
CREATE TABLE IF NOT EXISTS buy_requests (
  id                UUID                 PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID                 REFERENCES auth.users(id) ON DELETE SET NULL,
  name              TEXT                 NOT NULL,
  phone             TEXT                 NOT NULL,
  line_id           TEXT,
  property_type     TEXT,
  budget            NUMERIC(18,2)        DEFAULT 0,
  province          TEXT,
  transaction       TEXT,
  details           TEXT,
  status            request_status_enum  DEFAULT 'ใหม่',
  matched_prop_id   TEXT                 REFERENCES properties(id) ON DELETE SET NULL,
  admin_note        TEXT,
  consent_given     BOOLEAN              DEFAULT FALSE,
  consent_timestamp TIMESTAMPTZ,
  created_at        TIMESTAMPTZ          DEFAULT NOW(),
  updated_at        TIMESTAMPTZ          DEFAULT NOW()
);

-- favorites
CREATE TABLE IF NOT EXISTS favorites (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id TEXT        NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, property_id)
);

-- site_config (single row — id ล็อคไว้ที่ 1)
CREATE TABLE IF NOT EXISTS site_config (
  id         INT         PRIMARY KEY DEFAULT 1,
  addr       TEXT,
  phone      TEXT,
  line_id    TEXT,
  fb_url     TEXT,
  hero_sub   TEXT,
  srv_title  TEXT,
  srv_sub    TEXT,
  yt_url     TEXT,
  copyright  TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT site_config_single CHECK (id = 1)
);

-- admin_users
CREATE TABLE IF NOT EXISTS admin_users (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID        UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT        NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- legal_pages
CREATE TABLE IF NOT EXISTS legal_pages (
  id             TEXT        PRIMARY KEY,
  title          TEXT        NOT NULL,
  content        TEXT,
  version        TEXT        DEFAULT '1.0',
  effective_date TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. SAFE COLUMN ADDITIONS (รันซ้ำได้ไม่ error)
-- ============================================================
DO $$ BEGIN ALTER TABLE agents      ADD COLUMN IF NOT EXISTS photos  TEXT[]       DEFAULT '{}'; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE agents      ADD COLUMN IF NOT EXISTS rating  NUMERIC(3,2) DEFAULT 4.5;  EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS land_area    NUMERIC(12,2) DEFAULT 0;   EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS floors       INT DEFAULT 0;             EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS floor_no     INT DEFAULT 0;             EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS parking      INT DEFAULT 0;             EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS furniture    TEXT DEFAULT '';           EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS pets_allowed BOOLEAN DEFAULT FALSE;     EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE properties  ADD COLUMN IF NOT EXISTS appliances   TEXT[] DEFAULT '{}';       EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE listings    ADD COLUMN IF NOT EXISTS consent_given     BOOLEAN     DEFAULT FALSE; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE listings    ADD COLUMN IF NOT EXISTS consent_timestamp TIMESTAMPTZ;              EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE buy_requests ADD COLUMN IF NOT EXISTS consent_given     BOOLEAN     DEFAULT FALSE; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER TABLE buy_requests ADD COLUMN IF NOT EXISTS consent_timestamp TIMESTAMPTZ;              EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================
-- 4. AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DO $$ DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['agents','properties','blogs','listings','buy_requests','legal_pages'])
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_updated_at ON %I;
       CREATE TRIGGER trg_updated_at BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at();', t, t);
  END LOOP;
END $$;

-- ============================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE properties   ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents       ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio    ENABLE ROW LEVEL SECURITY;
ALTER TABLE services     ENABLE ROW LEVEL SECURITY;
ALTER TABLE blogs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_config  ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users  ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE buy_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites    ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_pages  ENABLE ROW LEVEL SECURITY;

-- Public READ
DROP POLICY IF EXISTS "public_read_properties"  ON properties;  CREATE POLICY "public_read_properties"  ON properties  FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "public_read_agents"      ON agents;      CREATE POLICY "public_read_agents"      ON agents      FOR SELECT USING (is_active = TRUE);
DROP POLICY IF EXISTS "public_read_portfolio"   ON portfolio;   CREATE POLICY "public_read_portfolio"   ON portfolio   FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "public_read_services"    ON services;    CREATE POLICY "public_read_services"    ON services    FOR SELECT USING (is_active = TRUE);
DROP POLICY IF EXISTS "public_read_blogs"       ON blogs;       CREATE POLICY "public_read_blogs"       ON blogs       FOR SELECT USING (is_published = TRUE);
DROP POLICY IF EXISTS "public_read_site_config" ON site_config; CREATE POLICY "public_read_site_config" ON site_config FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS "public_read_legal_pages" ON legal_pages; CREATE POLICY "public_read_legal_pages" ON legal_pages FOR SELECT USING (TRUE);

-- Admin WRITE site_config
DROP POLICY IF EXISTS "admin_write_site_config" ON site_config;
CREATE POLICY "admin_write_site_config" ON site_config
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- listings — user เห็นแค่ของตัวเอง
DROP POLICY IF EXISTS "listings_insert_auth" ON listings; CREATE POLICY "listings_insert_auth" ON listings FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "listings_select_own"  ON listings; CREATE POLICY "listings_select_own"  ON listings FOR SELECT USING  (auth.uid() = user_id);
DROP POLICY IF EXISTS "listings_update_own"  ON listings; CREATE POLICY "listings_update_own"  ON listings FOR UPDATE USING  (auth.uid() = user_id);

-- buy_requests — user เห็นแค่ของตัวเอง
DROP POLICY IF EXISTS "buyrq_insert_auth" ON buy_requests; CREATE POLICY "buyrq_insert_auth" ON buy_requests FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "buyrq_select_own"  ON buy_requests; CREATE POLICY "buyrq_select_own"  ON buy_requests FOR SELECT USING  (auth.uid() = user_id);
DROP POLICY IF EXISTS "buyrq_update_own"  ON buy_requests; CREATE POLICY "buyrq_update_own"  ON buy_requests FOR UPDATE USING  (auth.uid() = user_id);

-- favorites
DROP POLICY IF EXISTS "fav_all_own" ON favorites;
CREATE POLICY "fav_all_own" ON favorites USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 6. INDEXES
-- ============================================================
DROP INDEX IF EXISTS idx_properties_tx;            CREATE INDEX idx_properties_tx       ON properties(tx);
DROP INDEX IF EXISTS idx_properties_type;          CREATE INDEX idx_properties_type     ON properties(type);
DROP INDEX IF EXISTS idx_properties_province;      CREATE INDEX idx_properties_province ON properties(province);
DROP INDEX IF EXISTS idx_properties_price;         CREATE INDEX idx_properties_price    ON properties(price);
DROP INDEX IF EXISTS idx_properties_agent;         CREATE INDEX idx_properties_agent    ON properties(agent_id);
DROP INDEX IF EXISTS idx_properties_is_new;        CREATE INDEX idx_properties_is_new   ON properties(is_new)  WHERE is_new = TRUE;
DROP INDEX IF EXISTS idx_properties_is_rec;        CREATE INDEX idx_properties_is_rec   ON properties(is_rec)  WHERE is_rec = TRUE;
DROP INDEX IF EXISTS idx_properties_created;       CREATE INDEX idx_properties_created  ON properties(created_at DESC);
DROP INDEX IF EXISTS idx_properties_title_trgm;
DROP INDEX IF EXISTS idx_properties_loc_trgm;
DROP INDEX IF EXISTS idx_properties_desc_trgm;
CREATE INDEX idx_properties_title_trgm ON properties USING gin (title       gin_trgm_ops);
CREATE INDEX idx_properties_loc_trgm   ON properties USING gin (location    gin_trgm_ops);
CREATE INDEX idx_properties_desc_trgm  ON properties USING gin (description gin_trgm_ops);
DROP INDEX IF EXISTS idx_agents_active;    CREATE INDEX idx_agents_active    ON agents(is_active)            WHERE is_active = TRUE;
DROP INDEX IF EXISTS idx_portfolio_status; CREATE INDEX idx_portfolio_status ON portfolio(status);
DROP INDEX IF EXISTS idx_portfolio_type;   CREATE INDEX idx_portfolio_type   ON portfolio(type);
DROP INDEX IF EXISTS idx_portfolio_created;CREATE INDEX idx_portfolio_created ON portfolio(created_at DESC);
DROP INDEX IF EXISTS idx_blogs_published;  CREATE INDEX idx_blogs_published  ON blogs(is_published, sort_order) WHERE is_published = TRUE;
DROP INDEX IF EXISTS idx_services_active;  CREATE INDEX idx_services_active  ON services(is_active, sort_order) WHERE is_active = TRUE;
DROP INDEX IF EXISTS idx_listings_user;    CREATE INDEX idx_listings_user    ON listings(user_id);
DROP INDEX IF EXISTS idx_listings_status;  CREATE INDEX idx_listings_status  ON listings(status);
DROP INDEX IF EXISTS idx_buyrq_user;       CREATE INDEX idx_buyrq_user       ON buy_requests(user_id);
DROP INDEX IF EXISTS idx_buyrq_status;     CREATE INDEX idx_buyrq_status     ON buy_requests(status);
DROP INDEX IF EXISTS idx_fav_user;         CREATE INDEX idx_fav_user         ON favorites(user_id);
DROP INDEX IF EXISTS idx_fav_prop;         CREATE INDEX idx_fav_prop         ON favorites(property_id);

-- ============================================================
-- 7. SEED: agents (6 คน)
-- ============================================================
INSERT INTO agents (id, name, title, phone, line_id, initials, color, bio, avatar_url, photos, rating, is_active) VALUES
('a1','ปิยะวัฒน์ ทรงศิริ','ผู้จัดการฝ่ายขาย','081-100-2233','@piyawat','ปว','#7c6fcd',
 'ประสบการณ์กว่า 12 ปีในวงการอสังหาฯ กรุงเทพฯ และปริมณฑล เชี่ยวชาญด้านบ้านเดี่ยวและคอนโดระดับพรีเมียม มีผลงานปิดดีลกว่า 200 รายการ ได้รับรางวัลตัวแทนยอดเยี่ยมประจำปี 2567-2568',
 'https://randomuser.me/api/portraits/men/32.jpg',
 ARRAY['https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=600','https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600'],
 4.9,TRUE),

('a2','ศิริพร วงษ์สุวรรณ','ที่ปรึกษาอสังหาริมทรัพย์','082-200-3344','@siriporn','ศพ','#f06292',
 'เชี่ยวชาญคอนโดมิเนียมใจกลางเมือง ทำเล BTS/MRT ดูแลลูกค้าครบทุกขั้นตอน ตั้งแต่ค้นหา เจรจา จนถึงวันโอน ประสบการณ์ 9 ปี ลูกค้าซ้ำมากกว่า 60%',
 'https://randomuser.me/api/portraits/women/44.jpg',
 ARRAY['https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=600','https://images.unsplash.com/photo-1594744803329-e58b31de8bf5?w=600'],
 4.8,TRUE),

('a3','ภาณุพงศ์ เกียรติมงคล','ผู้เชี่ยวชาญที่ดินและบ้านหรู','083-300-4455','@panupong','ภง','#42a5f5',
 'ผู้เชี่ยวชาญอสังหาฯ ระดับลักซ์ชัวรี่ วิลล่า และที่ดินทุกประเภท มีฐานข้อมูลนักลงทุนกว่า 500 ราย ปิดดีลที่ดิน EEC มูลค่ากว่า 500 ล้านบาทในปี 2568',
 'https://randomuser.me/api/portraits/men/55.jpg',
 ARRAY['https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=600','https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=600'],
 4.7,TRUE),

('a4','กาญจนา บุญพระ','ที่ปรึกษาด้านการเช่า','084-400-5566','@kanjana','กญ','#66bb6a',
 'เชี่ยวชาญตลาดเช่า ทั้งระยะสั้นและระยะยาว ดูแลนักลงทุนให้ได้ผู้เช่าคุณภาพ ตรวจสอบประวัติผู้เช่าครบถ้วน ประสบการณ์ 7 ปี อัตราการปล่อยเช่าสำเร็จ 95%',
 'https://randomuser.me/api/portraits/women/61.jpg',
 ARRAY['https://images.unsplash.com/photo-1580489944761-15a19d654956?w=600','https://images.unsplash.com/photo-1614204424926-196a80bf0be8?w=600'],
 4.8,TRUE),

('a5','ณัฐพล อินทร์จันทร์','ผู้เชี่ยวชาญอสังหาฯ ชลบุรี-ระยอง','085-500-6677','@natthaphon','ณล','#ffa726',
 'เชี่ยวชาญอสังหาฯ ภาคตะวันออก EEC พัทยา ชลบุรี ระยอง ประสบการณ์กว่า 8 ปี เป็น Go-To Agent สำหรับนักลงทุนต่างชาติและบริษัทญี่ปุ่น/จีนที่เข้ามาลงทุนในนิคม',
 'https://randomuser.me/api/portraits/men/72.jpg',
 ARRAY['https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600','https://images.unsplash.com/photo-1463453091185-61582044d556?w=600'],
 4.6,TRUE),

('a6','อาภาพร ศรีวิชัย','ตัวแทนอสังหาฯ ภาคเหนือ','086-600-7788','@apaporn','อพ','#ab47bc',
 'ที่ปรึกษาอสังหาฯ เชียงใหม่-เชียงราย รีสอร์ท วิลล่า บ้านตากอากาศ ดอย เชี่ยวชาญตลาดต่างชาติ (Digital Nomad, Expat) ในเชียงใหม่ที่กำลังเติบโตอย่างรวดเร็ว',
 'https://randomuser.me/api/portraits/women/83.jpg',
 ARRAY['https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600','https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=600'],
 4.7,TRUE)

ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, title=EXCLUDED.title, phone=EXCLUDED.phone, line_id=EXCLUDED.line_id,
  initials=EXCLUDED.initials, color=EXCLUDED.color, bio=EXCLUDED.bio, avatar_url=EXCLUDED.avatar_url,
  photos=EXCLUDED.photos, rating=EXCLUDED.rating, is_active=EXCLUDED.is_active, updated_at=NOW();

-- ============================================================
-- 8. SEED: properties (45 รายการ — p01 ถึง p45)
-- ============================================================
INSERT INTO properties
  (id, title, type, province, location, price, tx, bed, bath, area, land_area,
   floors, floor_no, parking, furniture, pets_allowed, appliances,
   is_new, is_rec, description, agent_id, photos, created_at)
VALUES
-- ── บ้านเดี่ยว (p01–p06) ──────────────────────────────────
('p01','บ้านเดี่ยวหรู 3 ชั้น สุขุมวิท 77','บ้านเดี่ยว','กรุงเทพฯ','ออนนุช สุขุมวิท 77 กรุงเทพฯ',
 18500000,'BUY',4,4,380,80,3,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม'],TRUE,TRUE,
 'บ้านเดี่ยวสไตล์ Modern Luxury ใจกลางสุขุมวิท 3 ชั้น 4 ห้องนอน ห้องนั่งเล่นกว้าง สระว่ายน้ำส่วนตัว ระบบ Smart Home เดินทางสะดวกใกล้ BTS ออนนุช เพียง 500 เมตร ครัวยุโรป Built-in ทั้งหลัง ระบบกล้องวงจรปิด 24 ชั่วโมง สวนส่วนตัวร่มรื่น',
 'a1',ARRAY['https://images.unsplash.com/photo-1604328698692-f76ea9498e76?w=800','https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800','https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800','https://images.unsplash.com/photo-1565402170291-8491f14678db?w=800'],
 '2026-01-10'),

('p02','บ้านเดี่ยว 2 ชั้น สไตล์ Lanna เชียงใหม่','บ้านเดี่ยว','เชียงใหม่','แม่ริม เชียงใหม่',
 5800000,'BUY',3,3,200,100,2,0,2,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,
 'บ้านเดี่ยวสไตล์ล้านนาประยุกต์ บนที่ดิน 100 ตร.วา วิวดอยสุเทพ สวนสวย รับสัตว์เลี้ยง ใกล้โรงเรียน Chiang Mai International School เงียบสงบ อากาศดีตลอดปี เหมาะสำหรับครอบครัวที่ต้องการ Work from Home',
 'a6',ARRAY['https://images.unsplash.com/photo-1611117775350-ac3950990985?w=800','https://images.unsplash.com/photo-1605146769289-440113cc3d00?w=800','https://images.unsplash.com/photo-1560184897-67f4a3f9a7fa?w=800','https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=800'],
 '2026-01-15'),

('p03','บ้านเดี่ยวสไตล์มินิมัล โครงการ Grene ลำลูกกา','บ้านเดี่ยว','ปทุมธานี','ลำลูกกา คลอง 4 ปทุมธานี',
 4500000,'BUY',3,2,155,50,2,0,2,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'บ้านเดี่ยวสไตล์ Modern Minimal โครงการ Grene ลำลูกกา 3 ห้องนอน 2 ห้องน้ำ พื้นที่ใช้สอย 155 ตร.ม. บนที่ดิน 50 ตร.วา ใกล้ Future Park รังสิต และทางพิเศษ ราคาโปรโมชั่น ดอกเบี้ย 0% 2 ปีแรก',
 'a1',ARRAY['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800','https://images.unsplash.com/photo-1613545325278-f24b0cae1224?w=800','https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800','https://images.unsplash.com/photo-1572120360610-d971b9d7767c?w=800','https://images.unsplash.com/photo-1560184897-ae75f418493e?w=800'],
 '2026-01-20'),

('p04','บ้านเดี่ยวใหม่ หมู่บ้านพฤกษา สามพราน นครปฐม','บ้านเดี่ยว','นครปฐม','สามพราน นครปฐม',
 3200000,'BUY',3,2,145,55,2,0,2,'none',TRUE,
 ARRAY['แอร์'],TRUE,FALSE,
 'บ้านเดี่ยวใหม่โครงการพฤกษาวิลล์ สามพราน-นครปฐม โครงการปิด 100% ราคาดีที่สุดในย่าน ใกล้โรงพยาบาลนครปฐม ตลาดโรงเกลือ ทางหลวง 338 เดินทางเข้ากรุงเทพฯ 40 นาที',
 'a1',ARRAY['https://images.unsplash.com/photo-1543071220-6ee5bf71a54e?w=800','https://images.unsplash.com/photo-1505118380757-91f5f5632de0?w=800','https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?w=800','https://images.unsplash.com/photo-1516253593875-b1baa8b4a609?w=800','https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800'],
 '2026-01-25'),

('p05','บ้านเดี่ยวให้เช่า 2 ชั้น ย่านพระราม 9','บ้านเดี่ยว','กรุงเทพฯ','พระราม 9-ศรีนครินทร์ กรุงเทพฯ',
 45000,'RENT',3,3,220,60,2,0,2,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,TRUE,
 'บ้านเดี่ยว 2 ชั้น ให้เช่า ตกแต่งสวย เฟอร์นิเจอร์ครบ สวนหน้าบ้าน ใกล้ MRT พระราม 9 และ Central พระราม 9 เหมาะครอบครัวที่มีสัตว์เลี้ยง ที่จอดรถ 2 คัน สัญญาขั้นต่ำ 12 เดือน',
 'a1',ARRAY['https://images.unsplash.com/photo-1439792675105-701e6a4ab6f0?w=800','https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800','https://images.unsplash.com/photo-1623298317883-198303c50eed?w=800','https://images.unsplash.com/photo-1516455207474-a4887912729c?w=800','https://images.unsplash.com/photo-1484154218962-a197022b6967?w=800'],
 '2026-01-30'),

('p06','บ้านเดี่ยว 2 ชั้น หมู่บ้านเพอร์เฟค ขอนแก่น','บ้านเดี่ยว','ขอนแก่น','เมือง ขอนแก่น',
 2900000,'BUY',3,2,150,60,2,0,2,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,FALSE,
 'บ้านเดี่ยว 2 ชั้น โครงการเพอร์เฟค เพลส ใกล้ห้างเซ็นทรัลขอนแก่น มหาวิทยาลัยขอนแก่น และโรงพยาบาลศรีนครินทร์ ทำเลดีมาก ราคาจับต้องได้ เหมาะสำหรับครอบครัวรุ่นใหม่',
 'a4',ARRAY['https://images.unsplash.com/photo-1602343168117-bb8ffe3e2e9f?w=800','https://images.unsplash.com/photo-1628624747186-a941c476b7ef?w=800','https://images.unsplash.com/photo-1582719508491-a3a1e6b7e0e0?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800','https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800'],
 '2026-02-05'),

-- ── คอนโด (p07–p14) ─────────────────────────────────────────
('p07','คอนโด High-Rise วิวสาทร ชั้น 25','คอนโด','กรุงเทพฯ','สาทร-วิทยุ กรุงเทพฯ',
 6800000,'BUY',2,2,72,0,0,25,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ไมโครเวฟ','เครื่องซักผ้า'],TRUE,TRUE,
 'คอนโด High-Rise ชั้น 25 วิวพาโนรามาเมืองกรุง 180 องศา ใกล้ BTS ช่องนนทรี และ MRT ลุมพินี ตกแต่ง Built-in คุณภาพสูง สระว่ายน้ำบนชั้นดาดฟ้า ฟิตเนส Rooftop Sky Garden และ Co-working Space',
 'a2',ARRAY['https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=800','https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800','https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800','https://images.unsplash.com/photo-1592595896616-c37162298647?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800'],
 '2026-02-08'),

('p08','คอนโด Riverside Luxury วิวแม่น้ำ ICON SIAM','คอนโด','กรุงเทพฯ','เจริญนคร-ICONSIAM กรุงเทพฯ',
 9500000,'BUY',2,2,78,0,0,22,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],TRUE,TRUE,
 'คอนโด High-Rise ริมแม่น้ำเจ้าพระยา ชั้น 22 วิว ICONSIAM และแม่น้ำ 180 องศา ตกแต่ง Built-in Italian Style ห้องนอนใหญ่ 30 ตร.ม. สระว่ายน้ำ Infinity และ Sky Lounge เรือรับ-ส่ง ICONSIAM ฟรี',
 'a2',ARRAY['https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?w=800','https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=800','https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800','https://images.unsplash.com/photo-1556020685-ae41abfc9365?w=800','https://images.unsplash.com/photo-1560185008-b033106af5c3?w=800'],
 '2026-02-10'),

('p09','คอนโดให้เช่า ห้องสตูดิโอ ใจกลางอโศก','คอนโด','กรุงเทพฯ','อโศก-สุขุมวิท กรุงเทพฯ',
 22000,'RENT',0,1,32,0,0,8,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี','เครื่องซักผ้า'],FALSE,TRUE,
 'คอนโดสตูดิโอ เฟอร์นิเจอร์ครบทั้งห้อง ชั้น 8 วิวเมือง ใกล้ BTS อโศก + MRT สุขุมวิท เดินได้ 5 นาที เหมาะมนุษย์เงินเดือนและผู้ทำงานย่านธุรกิจ รักษาความปลอดภัย 24 ชั่วโมง',
 'a2',ARRAY['https://images.unsplash.com/photo-1619994403073-2cec844b8e63?w=800','https://images.unsplash.com/photo-1614168092736-01bd2b8c8821?w=800','https://images.unsplash.com/photo-1600210492493-0946911123ea?w=800','https://images.unsplash.com/photo-1562182384-08115de5ee97?w=800','https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800'],
 '2026-02-12'),

('p10','คอนโดให้เช่า ใกล้ MRT ลาดพร้าว ราคาประหยัด','คอนโด','กรุงเทพฯ','ลาดพร้าว-เสนานิคม กรุงเทพฯ',
 9500,'RENT',1,1,28,0,0,5,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี'],FALSE,FALSE,
 'คอนโดสตูดิโอ เฟอร์นิเจอร์ครบ ชั้น 5 วิวสวนหย่อม ใกล้ MRT ลาดพร้าว รักษาความปลอดภัย 24 ชั่วโมง เหมาะนักศึกษาและมนุษย์เงินเดือน งบจำกัด อินเตอร์เน็ต Fiber รวมแล้ว',
 'a4',ARRAY['https://images.unsplash.com/photo-1441986300927-91d9e4a5e1fc?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800','https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800','https://images.unsplash.com/photo-1463453091185-61582044d556?w=800'],
 '2026-02-15'),

('p11','คอนโดให้เช่า วิวทะเล พัทยา ชั้น 15','คอนโด','ชลบุรี','พัทยากลาง ชลบุรี',
 35000,'RENT',2,1,55,0,0,15,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโดให้เช่าระยะยาว ชั้น 15 วิวอ่าวพัทยา 180 องศา ตกแต่งสวย เฟอร์นิเจอร์ครบ ห้องน้ำทันสมัย สระว่ายน้ำชั้นดาดฟ้า ฟิตเนส เหมาะ Expat และนักลงทุนต่างชาติ',
 'a5',ARRAY['https://images.unsplash.com/photo-1540519338287-7c3f9a68ac3d?w=800','https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800','https://images.unsplash.com/photo-1565182999561-18d7dc61c393?w=800','https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
 '2026-02-18'),

('p12','คอนโด 1 ห้องนอน สุขุมวิท 101 ใกล้ BTS ปุณณวิถี','คอนโด','กรุงเทพฯ','สุขุมวิท 101 ปุณณวิถี กรุงเทพฯ',
 4200000,'BUY',1,1,42,0,0,12,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,FALSE,
 'คอนโด 1 ห้องนอน ตกแต่ง Built-in สไตล์ Scandinavian ชั้น 12 ใกล้ BTS ปุณณวิถีเพียง 300 เมตร วิวเมือง สระว่ายน้ำและฟิตเนสชั้นดาดฟ้า ใกล้ Tesco Lotus สุขุมวิท 101',
 'a2',ARRAY['https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800','https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800','https://images.unsplash.com/photo-1600210491892-03d54c0aaf87?w=800','https://images.unsplash.com/photo-1628744448840-55bdb2497bd4?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],
 '2026-02-20'),

('p13','คอนโดให้เช่า ย่านนิมมาน เชียงใหม่ วิวดอย','คอนโด','เชียงใหม่','นิมมานเหมินท์ เชียงใหม่',
 18000,'RENT',1,1,38,0,0,6,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี','เครื่องซักผ้า'],FALSE,TRUE,
 'คอนโดสไตล์ Loft ย่านนิมมาน ให้เช่า เฟอร์นิเจอร์ครบ วิวดอยสุเทพ ใกล้ร้านกาแฟ ร้านอาหาร ย่านช้อปปิ้ง เหมาะ Digital Nomad และชาวต่างชาติ อินเตอร์เน็ต Fiber รวม',
 'a6',ARRAY['https://images.unsplash.com/photo-1617325247661-675ab4b64ae2?w=800','https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800','https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800','https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=800'],
 '2026-02-22'),

('p14','Penthouse ทองหล่อ 3 ห้องนอน วิวพาโนราม่า','คอนโด','กรุงเทพฯ','ทองหล่อ สุขุมวิท 55 กรุงเทพฯ',
 28000000,'BUY',3,3,220,0,0,40,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','ไมโครเวฟ'],FALSE,TRUE,
 'Penthouse หายาก ชั้น 40 ย่านทองหล่อ วิวพาโนราม่า 360 องศา ระเบียงส่วนตัวขนาดใหญ่ ตกแต่งสไตล์ Designer สุดหรู Kitchen Island ขนาด 3 เมตร Concierge ส่วนตัว วาเล่ต์พาร์กกิ้ง',
 'a2',ARRAY['https://images.unsplash.com/photo-1560448205-4d0b7db08ede?w=800','https://images.unsplash.com/photo-1591474200742-8e512e6f98f8?w=800','https://images.unsplash.com/photo-1507089947368-19c1da9775ae?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800','https://images.unsplash.com/photo-1534430480882-96c9102bcf71?w=800'],
 '2026-02-25'),

-- ── ทาวน์โฮม (p15–p19) ──────────────────────────────────────
('p15','ทาวน์โฮม Premium 3 ชั้น ใกล้ MRT แจ้งวัฒนะ','ทาวน์โฮม','นนทบุรี','แจ้งวัฒนะ ปากเกร็ด นนทบุรี',
 4200000,'BUY',3,3,175,28,3,0,2,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,FALSE,
 'ทาวน์โฮม 3 ชั้น โครงการใหม่ ใกล้สถานี MRT แจ้งวัฒนะ ห้องกว้าง ที่จอดรถ 2 คัน ครัวเปิด Living Room ยาว 7 เมตร ตกแต่ง Built-in ทั้งหลัง รับสัตว์เลี้ยงได้ สวนหน้าบ้านร่มรื่น',
 'a1',ARRAY['https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=800','https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800','https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800','https://images.unsplash.com/photo-1467533003447-e295ff1b0435?w=800'],
 '2026-03-01'),

('p16','ทาวน์โฮมให้เช่า 2 ชั้น ใกล้ Mega Bangna','ทาวน์โฮม','กรุงเทพฯ','บางนา-ตราด กม.9 กรุงเทพฯ',
 18000,'RENT',3,2,120,20,2,0,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,FALSE,
 'ทาวน์โฮม 2 ชั้น ให้เช่า ตกแต่งบางส่วน ใกล้ Mega Bangna 10 นาที ใกล้สนามบินสุวรรณภูมิ รับสัตว์เลี้ยง ที่จอดรถ 1 คัน เหมาะครอบครัวขนาดกลาง ค่าเช่ารวมค่าส่วนกลางหมู่บ้าน',
 'a4',ARRAY['https://images.unsplash.com/photo-1599427303058-f04cbcf4756f?w=800','https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=800'],
 '2026-03-05'),

('p17','ทาวน์โฮม 3 ชั้น รังสิต ราคาคุ้มค่า','ทาวน์โฮม','ปทุมธานี','รังสิต-นครนายก ปทุมธานี',
 2800000,'BUY',2,2,110,18,3,0,1,'none',FALSE,
 ARRAY['แอร์'],FALSE,FALSE,
 'ทาวน์โฮม 3 ชั้น ราคาจับต้องได้ ใกล้มหาวิทยาลัยรังสิต โรงเรียนนานาชาติ และห้างฟิวเจอร์ พาร์ค ทำเลดี เดินทางสะดวก เหมาะซื้อลงทุนปล่อยเช่านักศึกษา ผลตอบแทน 6-7% ต่อปี',
 'a4',ARRAY['https://images.unsplash.com/photo-1600566752447-b00f67e74a0e?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800'],
 '2026-03-08'),

('p18','ทาวน์โฮม 4 ชั้น หรูใจกลาง On Nut','ทาวน์โฮม','กรุงเทพฯ','อ่อนนุช สุขุมวิท 77 กรุงเทพฯ',
 7500000,'BUY',4,4,260,35,4,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'ทาวน์โฮม 4 ชั้น Premium ย่านอ่อนนุช บันไดหินอ่อน ห้องนั่งเล่น Double Volume ระบบ Smart Home ใกล้ BTS อ่อนนุช 600 เมตร ครัว Island ขนาดใหญ่ ดาดฟ้าส่วนตัว',
 'a1',ARRAY['https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=800','https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?w=800','https://images.unsplash.com/photo-1565372195458-cf3eced61daf?w=800','https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800','https://images.unsplash.com/photo-1599619585752-c3edb42a414c?w=800'],
 '2026-03-10'),

('p19','ทาวน์โฮมให้เช่า ใกล้สุวรรณภูมิ ลาดกระบัง','ทาวน์โฮม','กรุงเทพฯ','ลาดกระบัง กรุงเทพฯ',
 15000,'RENT',3,2,130,25,2,0,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'ทาวน์โฮม 2 ชั้น ให้เช่า ใกล้สนามบินสุวรรณภูมิ 15 นาที สถาบันเทคโนโลยีพระจอมเกล้าลาดกระบัง เหมาะพนักงานสายการบิน นักศึกษา ครอบครัวเล็ก รับสัตว์เลี้ยงได้',
 'a4',ARRAY['https://images.unsplash.com/photo-1613490493576-5f6ce62b17c9?w=800','https://images.unsplash.com/photo-1484301548518-d0e0a5db0fc8?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800','https://images.unsplash.com/photo-1574691250077-03a929faece5?w=800'],
 '2026-03-12'),

-- ── วิลล่า (p20–p22) ─────────────────────────────────────────
('p20','วิลล่า Pool Villa หาดบางเทา ภูเก็ต','วิลล่า','ภูเก็ต','เชิงทะเล อ.ถลาง ภูเก็ต',
 22000000,'BUY',4,4,420,120,2,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'วิลล่าสไตล์ Tropical Luxury ห่างชายหาดบางเทาเพียง 300 เมตร สระว่ายน้ำส่วนตัวยาว 12 เมตร สวนเขตร้อนร่มรื่น 4 ห้องนอนล้วนมีห้องน้ำในตัว เหมาะลงทุนปล่อยเช่า Holiday Rental คาด Yield 8-10% ต่อปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1598994942340-0a2e0e11c5bc?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800'],
 '2026-03-15'),

('p21','วิลล่าตากอากาศ วิวดอย เชียงใหม่','วิลล่า','เชียงใหม่','ดอยสะเก็ด เชียงใหม่',
 8900000,'BUY',3,3,280,200,2,0,3,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เตาผิง'],TRUE,TRUE,
 'วิลล่าตากอากาศ สไตล์ Rustic Luxury วิวภูเขาและดอยสะเก็ด สระน้ำร้อนส่วนตัว เตาผิง อากาศเย็นสบายตลอดปี บนที่ดิน 200 ตร.วา รับสัตว์เลี้ยง ห่างเมืองเชียงใหม่ 20 นาที',
 'a6',ARRAY['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800','https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800','https://images.unsplash.com/photo-1502672023488-70e25813eb80?w=800'],
 '2026-03-18'),

('p22','วิลล่าให้เช่า วิวทะเล เกาะสมุย','วิลล่า','สุราษฎร์ธานี','เฉวง เกาะสมุย สุราษฎร์ธานี',
 120000,'RENT',3,3,320,150,2,0,4,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'วิลล่าให้เช่ารายเดือน/รายปี วิวอ่าวเฉวง 180 องศา สระว่ายน้ำ Infinity ริมหน้าผา ตกแต่งหรู Chef Kitchen Sala ริมสระ เหมาะ Luxury Holiday Retreat และนักลงทุนทำ AirBnB',
 'a3',ARRAY['https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-03-20'),

-- ── ที่ดิน (p23–p26) ─────────────────────────────────────────
('p23','ที่ดินอุตสาหกรรม ใกล้นิคม EEC ชลบุรี','ที่ดิน','ชลบุรี','อ.ศรีราชา ชลบุรี',
 18000000,'BUY',0,0,0,1600,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'ที่ดิน 4 ไร่ ติดถนน 4 เลน ใกล้นิคมอุตสาหกรรม Amata City มีโฉนดพร้อมโอน ไฟฟ้า 3 เฟส น้ำประปา ท่อระบายน้ำ เหมาะลงทุนสร้างโกดัง/โรงงาน ราคา EEC กำลังขึ้น ใกล้สนามบินอู่ตะเภา 40 นาที',
 'a5',ARRAY['https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800','https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800','https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=800','https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800'],
 '2026-03-22'),

('p24','ที่ดินเปล่า ทำเลทอง ติดถนนใหญ่ สมุทรปราการ','ที่ดิน','สมุทรปราการ','เทพารักษ์ บางพลี สมุทรปราการ',
 7200000,'BUY',0,0,0,280,0,0,0,'none',FALSE,ARRAY[]::TEXT[],TRUE,FALSE,
 'ที่ดินเปล่า 280 ตร.วา ติดถนน 4 เลน หน้ากว้าง 28 เมตร ลึก 40 เมตร โฉนดพร้อมโอน ใกล้ห้างพาราไดซ์ พาร์ค และ Central Bangna เหมาะสร้างบ้าน ร้านค้า หรือหอพัก',
 'a5',ARRAY['https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800','https://images.unsplash.com/photo-1576673442511-7e39b6545c87?w=800','https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800','https://images.unsplash.com/photo-1497366754035-91ee15a9d7e2?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'],
 '2026-03-24'),

('p25','ที่ดินเชิงพาณิชย์ ริมถนน เชียงราย','ที่ดิน','เชียงราย','เมือง เชียงราย',
 3500000,'BUY',0,0,0,200,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดินหน้าถนนพหลโยธิน ขนาด 200 ตร.วา ในเขตเทศบาลเมืองเชียงราย เหมาะสร้างร้านค้า ร้านอาหาร หรือโชวรูม ใกล้ตลาดอินโดจีน และสนามบินเชียงราย 10 นาที',
 'a5',ARRAY['https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800','https://images.unsplash.com/photo-1583621212985-a8d6a0dcbab5?w=800','https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800','https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],
 '2026-03-26'),

('p26','ที่ดินเกษตรกรรม ริมน้ำ พระนครศรีอยุธยา','ที่ดิน','พระนครศรีอยุธยา','บางบาล พระนครศรีอยุธยา',
 2800000,'BUY',0,0,0,800,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดินเกษตร 2 ไร่ ริมแม่น้ำ โฉนดครุฑ ดินดี น้ำพอเพียงตลอดปี เหมาะปลูกผัก ทำสวนผลไม้ หรือทำบ้านชนบทตากอากาศ ห่างกรุงเทพฯ 80 กม. เดินทางสะดวกทางถนนสาย 32',
 'a5',ARRAY['https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800','https://images.unsplash.com/photo-1558442074-3c19857bc1dc?w=800','https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
 '2026-03-28'),

-- ── อาคารพาณิชย์ (p27–p29) ──────────────────────────────────
('p27','อาคารพาณิชย์ 5 ชั้น ย่านรัชดาภิเษก','อาคารพาณิชย์','กรุงเทพฯ','รัชดาภิเษก-ห้วยขวาง กรุงเทพฯ',
 12500000,'BUY',0,4,240,28,5,0,2,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'อาคารพาณิชย์ 5 ชั้น หน้ากว้าง 5.5 เมตร ย่านธุรกิจรัชดา ใกล้ MRT ห้วยขวาง ลิฟต์โดยสาร ระบบไฟฟ้า 3 เฟส เหมาะสำนักงาน คลินิก หรือ Showroom สินค้า รายได้จากเช่าปัจจุบัน 45,000 บาท/เดือน',
 'a3',ARRAY['https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800','https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800','https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=800','https://images.unsplash.com/photo-1484101403633-562f891dc89a?w=800'],
 '2026-04-01'),

('p28','อาคารสำนักงานให้เช่า ชั้น 3 ติวานนท์ นนทบุรี','อาคารพาณิชย์','นนทบุรี','ติวานนท์ เมือง นนทบุรี',
 28000,'RENT',0,2,150,0,4,3,2,'partial',FALSE,
 ARRAY['แอร์','อินเตอร์เน็ต'],FALSE,FALSE,
 'พื้นที่สำนักงานให้เช่า ชั้น 3 ขนาด 150 ตร.ม. อาคารมีลิฟต์ ที่จอดรถ 2 คัน ใกล้ศูนย์ราชการนนทบุรี สถานี MRT กระทรวงสาธารณสุข เหมาะบริษัท SME และ Startup',
 'a3',ARRAY['https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800','https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800','https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2026-04-03'),

('p29','ตึกแถว 4 ชั้น ย่านลาดพร้าว ทำเลทอง','อาคารพาณิชย์','กรุงเทพฯ','ลาดพร้าว 71 กรุงเทพฯ',
 8900000,'BUY',0,3,180,22,4,0,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ตึกแถว 4 ชั้น หน้ากว้าง 5 เมตร ย่านลาดพร้าว ใกล้ MRT บางกะปิ เหมาะเปิดร้านชั้นล่าง และอยู่อาศัยชั้นบน ปัจจุบันปล่อยเช่า 35,000 บาท/เดือน ผลตอบแทน 4.7% ต่อปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1615529328331-f8917597711f?w=800','https://images.unsplash.com/photo-1497366216548-37526070297c?w=800','https://images.unsplash.com/photo-1615571022219-eb45cf7faa9d?w=800'],
 '2026-04-05'),

-- ── รีสอร์ท (p30) ────────────────────────────────────────────
('p30','รีสอร์ท 12 ห้อง ติดชายหาดหัวหิน','รีสอร์ท','ประจวบคีรีขันธ์','หัวหิน ประจวบคีรีขันธ์',
 35000000,'BUY',12,12,1200,400,2,0,20,'full',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'รีสอร์ทพรีเมียม 12 ห้อง ติดชายหาดหัวหิน สระว่ายน้ำขนาดใหญ่ ร้านอาหาร บาร์ริมหาด รายได้ดีตลอดปี Occupancy เฉลี่ย 75% เหมาะนักลงทุนธุรกิจโรงแรม คืนทุนภายใน 7-8 ปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800','https://images.unsplash.com/photo-1613545325268-2f15f20d2670?w=800'],
 '2026-04-07'),

-- ============================================================
-- ✨ รายการใหม่ p31–p45 (เพิ่มเติม 15 รายการ)
-- ============================================================

-- ── บ้านเดี่ยวเพิ่มเติม (p31–p33) ──────────────────────────
('p31','บ้านเดี่ยว 2 ชั้น โครงการ SC Asset นนทบุรี','บ้านเดี่ยว','นนทบุรี','บางใหญ่ นนทบุรี',
 6200000,'BUY',4,3,210,72,2,0,2,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,
 'บ้านเดี่ยว 2 ชั้น โครงการ SC Grand Pinklao บางใหญ่ ขนาดใหญ่ 4 ห้องนอน ห้องนั่งเล่น Double Space สวนหน้าบ้านร่มรื่น ใกล้ MRT บางใหญ่ ห้างเซ็นทรัลเวสต์เกต ระบบรักษาความปลอดภัย 24 ชม.',
 'a1',ARRAY['https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800','https://images.unsplash.com/photo-1507089947368-19c1da9775ae?w=800','https://images.unsplash.com/photo-1605146769289-440113cc3d00?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'],
 '2026-04-09'),

('p32','บ้านเดี่ยวให้เช่า หมู่บ้าน Perfect Place ระยอง','บ้านเดี่ยว','ระยอง','เมือง ระยอง',
 28000,'RENT',3,2,160,55,2,0,2,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,FALSE,
 'บ้านเดี่ยว 2 ชั้น ให้เช่า เฟอร์นิเจอร์ครบ รับสัตว์เลี้ยง ใกล้นิคมอุตสาหกรรมมาบตาพุด เหมาะพนักงานโรงงาน ครอบครัวชาวต่างชาติ ที่จอดรถ 2 คัน สัญญาอย่างน้อย 6 เดือน',
 'a5',ARRAY['https://images.unsplash.com/photo-1513584684374-8bab748fbf90?w=800','https://images.unsplash.com/photo-1623298317883-198303c50eed?w=800','https://images.unsplash.com/photo-1484154218962-a197022b6967?w=800','https://images.unsplash.com/photo-1439792675105-701e6a4ab6f0?w=800','https://images.unsplash.com/photo-1516455207474-a4887912729c?w=800'],
 '2026-04-11'),

('p33','บ้านเดี่ยวหรู 3 ชั้น Prestige สุขุมวิท 49','บ้านเดี่ยว','กรุงเทพฯ','ทองหล่อ สุขุมวิท 49 กรุงเทพฯ',
 35000000,'BUY',5,5,480,90,3,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม','โฮมเธียเตอร์'],FALSE,TRUE,
 'บ้านเดี่ยวระดับ Ultra Luxury ย่านทองหล่อ 5 ห้องนอน ทุกห้องมี Walk-in Closet และห้องน้ำ En-suite สระว่ายน้ำส่วนตัว Jacuzzi ห้อง Wine Cellar ลิฟต์ภายในบ้าน ห้องพักแม่บ้าน ใกล้ BTS ทองหล่อ 400 เมตร',
 'a1',ARRAY['https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800','https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800','https://images.unsplash.com/photo-1560185008-b033106af5c3?w=800'],
 '2026-04-13'),

-- ── คอนโดเพิ่มเติม (p34–p37) ────────────────────────────────
('p34','คอนโดใหม่ 2 ห้องนอน ใกล้ Airport Link พญาไท','คอนโด','กรุงเทพฯ','พญาไท-ราชเทวี กรุงเทพฯ',
 5900000,'BUY',2,2,58,0,0,18,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,
 'คอนโดใหม่ปี 2568 ชั้น 18 ใกล้ BTS พญาไท และ Airport Link เพียง 200 เมตร ตกแต่ง Built-in ทั้งห้อง วิวเมืองสวยงาม สระว่ายน้ำบนชั้นดาดฟ้า ฟิตเนส Sky Lounge เหมาะคนทำงานย่านราชดำเนิน-พระนคร',
 'a2',ARRAY['https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800','https://images.unsplash.com/photo-1600210491892-03d54c0aaf87?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800','https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800'],
 '2026-04-15'),

('p35','คอนโดให้เช่า Sea View หาดจอมเทียน พัทยา','คอนโด','ชลบุรี','จอมเทียน พัทยาใต้ ชลบุรี',
 18000,'RENT',1,1,40,0,0,10,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี','เครื่องซักผ้า'],FALSE,TRUE,
 'คอนโด 1 ห้องนอน ชั้น 10 วิวทะเลจอมเทียน 180 องศา เฟอร์นิเจอร์ครบ ให้เช่ารายเดือน/รายปี สระว่ายน้ำ ฟิตเนส จักรยาน ใกล้ Walking Street พัทยาใต้ เหมาะ Expat และนักท่องเที่ยวระยะยาว',
 'a5',ARRAY['https://images.unsplash.com/photo-1540519338287-7c3f9a68ac3d?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800','https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800','https://images.unsplash.com/photo-1565182999561-18d7dc61c393?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800'],
 '2026-04-17'),

('p36','คอนโด 2 ห้องนอน ใหม่ แยกรัชโยธิน กรุงเทพฯ','คอนโด','กรุงเทพฯ','รัชโยธิน-พหลโยธิน กรุงเทพฯ',
 4800000,'BUY',2,2,55,0,0,14,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,FALSE,
 'คอนโด 2 ห้องนอน โครงการใหม่ ชั้น 14 ใกล้ MRT รัชโยธิน และสถานีกลางบางซื่อ ตกแต่ง Modern Minimal สระว่ายน้ำ ฟิตเนส EV Charger ในที่จอดรถ ใกล้เซ็นทรัล ลาดพร้าว',
 'a2',ARRAY['https://images.unsplash.com/photo-1619994403073-2cec844b8e63?w=800','https://images.unsplash.com/photo-1614168092736-01bd2b8c8821?w=800','https://images.unsplash.com/photo-1600210492493-0946911123ea?w=800','https://images.unsplash.com/photo-1628744448840-55bdb2497bd4?w=800','https://images.unsplash.com/photo-1562182384-08115de5ee97?w=800'],
 '2026-04-19'),

('p37','คอนโดให้เช่า ใกล้ ม.เชียงใหม่ นิมมาน','คอนโด','เชียงใหม่','ห้วยแก้ว-นิมมาน เชียงใหม่',
 12000,'RENT',1,1,35,0,0,4,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี'],FALSE,FALSE,
 'คอนโด 1 ห้องนอน ชั้น 4 ใกล้มหาวิทยาลัยเชียงใหม่ ย่านนิมมาน ฟิตเนส สระว่ายน้ำ อินเตอร์เน็ต Fiber รวม เหมาะนักศึกษา อาจารย์ Digital Nomad ทำเล Walkable ถึงร้านกาแฟดัง',
 'a6',ARRAY['https://images.unsplash.com/photo-1617325247661-675ab4b64ae2?w=800','https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800','https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=800','https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800'],
 '2026-04-21'),

-- ── ทาวน์โฮมเพิ่มเติม (p38–p39) ─────────────────────────────
('p38','ทาวน์โฮม 3 ชั้น ใกล้ BTS สำโรง สมุทรปราการ','ทาวน์โฮม','สมุทรปราการ','สำโรง-บางนา สมุทรปราการ',
 3500000,'BUY',3,3,165,22,3,0,2,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,FALSE,
 'ทาวน์โฮม 3 ชั้น โครงการใหม่ ห่าง BTS สำโรงเพียง 800 เมตร ใกล้ห้างพาราไดซ์ พาร์ค โรงพยาบาลสมิติเวช ศรีนครินทร์ ที่จอดรถ 2 คัน ห้องนั่งเล่นกว้าง ครัวเปิด',
 'a4',ARRAY['https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=800','https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800','https://images.unsplash.com/photo-1467533003447-e295ff1b0435?w=800','https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800'],
 '2026-04-22'),

('p39','ทาวน์โฮมให้เช่า 3 ชั้น ย่านอารีย์ กรุงเทพฯ','ทาวน์โฮม','กรุงเทพฯ','อารีย์-สะพานควาย กรุงเทพฯ',
 35000,'RENT',3,3,185,30,3,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'ทาวน์โฮม 3 ชั้น ใจกลางย่านอารีย์ ให้เช่า เฟอร์นิเจอร์ครบ ใกล้ BTS อารีย์ 400 เมตร ห้องนั่งเล่นชั้น 1 โล่งกว้าง สวนหน้าบ้าน ที่จอดรถ 2 คัน เหมาะครอบครัวที่ต้องการพื้นที่ กลางเมือง',
 'a1',ARRAY['https://images.unsplash.com/photo-1599427303058-f04cbcf4756f?w=800','https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800'],
 '2026-04-24'),

-- ── วิลล่าและรีสอร์ทเพิ่มเติม (p40–p41) ─────────────────────
('p40','วิลล่า Pool Villa ใหม่ บ้านเอื้อม กระบี่','วิลล่า','กระบี่','อ่าวนาง กระบี่',
 15000000,'BUY',3,3,350,180,1,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'วิลล่าสไตล์ Balinese ชั้นเดียว บนเนินเขาติดทะเลกระบี่ สระว่ายน้ำส่วนตัว วิวอ่าวนาง 180 องศา ตกแต่งไม้สักแท้ สวนเขตร้อน Sala ริมสระ เหมาะลงทุน AirBnB ช่วง High Season คาด Yield 12% ต่อปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800','https://images.unsplash.com/photo-1598994942340-0a2e0e11c5bc?w=800'],
 '2026-04-26'),

('p41','โรงแรม Boutique 20 ห้อง ย่านเจริญกรุง กรุงเทพฯ','โรงแรม','กรุงเทพฯ','เจริญกรุง-บางรัก กรุงเทพฯ',
 85000000,'BUY',20,20,1800,0,6,0,10,'full',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'โรงแรม Boutique 6 ชั้น 20 ห้อง ย่านเจริญกรุง ทรัพย์สินเดิมพร้อม License โรงแรม Occupancy เฉลี่ย 80% ADR 2,500 บาท/คืน รายได้สุทธิประมาณ 8 ล้านบาท/ปี ใกล้ Asiatique และ ICON SIAM ตลาดนักท่องเที่ยวสูง',
 'a3',ARRAY['https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800','https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1613545325268-2f15f20d2670?w=800'],
 '2026-04-28'),

-- ── ที่ดินเพิ่มเติม (p42–p43) ────────────────────────────────
('p43','ที่ดินพัฒนา ใกล้รถไฟฟ้าสายสีม่วง นนทบุรี','ที่ดิน','นนทบุรี','เตาปูน-บางซื่อ นนทบุรี',
 9800000,'BUY',0,0,0,320,0,0,0,'none',FALSE,ARRAY[]::TEXT[],TRUE,FALSE,
 'ที่ดินเปล่า 320 ตร.วา ติดถนน 4 เลน ใกล้สถานี MRT เตาปูน (จุดเชื่อมต่อสายสีน้ำเงิน-ม่วง) โฉนดพร้อมโอน ไฟฟ้า 3 เฟส ประปาเข้าถึง เหมาะสร้างอาคารชุด Condo Low-Rise หรือหอพัก',
 'a5',ARRAY['https://images.unsplash.com/photo-1583621212985-a8d6a0dcbab5?w=800','https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800','https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800','https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],
 '2026-04-29'),

('p42','ที่ดินเพื่อการพาณิชย์ ถนนเลียบทางด่วน สมุทรสาคร','ที่ดิน','สมุทรสาคร','กระทุ่มแบน สมุทรสาคร',
 5500000,'BUY',0,0,0,480,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดิน 1 ไร่ 200 ตร.วา ติดถนนพระราม 2 เหมาะทำคลังสินค้า โกดัง หรือโรงงานขนาดเล็ก ใกล้นิคมอุตสาหกรรมสมุทรสาคร ไฟฟ้าและประปาพร้อม เส้นทางขนส่งสะดวก',
 'a5',ARRAY['https://images.unsplash.com/photo-1576673442511-7e39b6545c87?w=800','https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=800','https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800','https://images.unsplash.com/photo-1497366754035-91ee15a9d7e2?w=800'],
 '2026-04-30'),

-- ── อาคารพาณิชย์เพิ่มเติม (p44–p45) ────────────────────────
('p44','อาคารพาณิชย์ให้เช่า 3 ชั้น ย่านสีลม กรุงเทพฯ','อาคารพาณิชย์','กรุงเทพฯ','สีลม-ศาลาแดง กรุงเทพฯ',
 75000,'RENT',0,3,200,0,3,0,2,'partial',FALSE,
 ARRAY['แอร์','อินเตอร์เน็ต'],FALSE,TRUE,
 'อาคารพาณิชย์ให้เช่า 3 ชั้น ย่านธุรกิจสีลม หน้ากว้าง 6 เมตร ใกล้ BTS ศาลาแดง และ MRT สีลม เหมาะสำนักงาน คลินิก ร้านอาหาร หรือ Pop-up Store ระดับพรีเมียม สัญญา 2 ปีขึ้นไป',
 'a3',ARRAY['https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800','https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=800','https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800','https://images.unsplash.com/photo-1484101403633-562f891dc89a?w=800'],
 '2026-05-01'),

('p45','ตึกแถว 5 ชั้น ห้องมุม ย่านประตูน้ำ กรุงเทพฯ','อาคารพาณิชย์','กรุงเทพฯ','ประตูน้ำ-ราชปรารภ กรุงเทพฯ',
 16500000,'BUY',0,5,300,32,5,0,2,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ตึกแถวหัวมุม 5 ชั้น ย่านค้าส่งประตูน้ำ หน้ากว้าง 10 เมตร สองด้าน ลิฟต์โดยสาร ไฟฟ้า 3 เฟส ปัจจุบันเช่า 80,000 บาท/เดือน ผลตอบแทน 5.8% ต่อปี ใกล้ BTS ราชเทวี และ Central World',
 'a3',ARRAY['https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1615571022219-eb45cf7faa9d?w=800','https://images.unsplash.com/photo-1497366216548-37526070297c?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1615529328331-f8917597711f?w=800'],
 '2026-05-03')

ON CONFLICT (id) DO UPDATE SET
  title=EXCLUDED.title, type=EXCLUDED.type, province=EXCLUDED.province,
  location=EXCLUDED.location, price=EXCLUDED.price, tx=EXCLUDED.tx,
  bed=EXCLUDED.bed, bath=EXCLUDED.bath, area=EXCLUDED.area, land_area=EXCLUDED.land_area,
  floors=EXCLUDED.floors, floor_no=EXCLUDED.floor_no, parking=EXCLUDED.parking,
  furniture=EXCLUDED.furniture, pets_allowed=EXCLUDED.pets_allowed, appliances=EXCLUDED.appliances,
  is_new=EXCLUDED.is_new, is_rec=EXCLUDED.is_rec, description=EXCLUDED.description,
  agent_id=EXCLUDED.agent_id, photos=EXCLUDED.photos, updated_at=NOW();

-- ============================================================
-- 9. SEED: portfolio (8 ผลงาน — เพิ่มอีก 3 รายการ)
-- ============================================================
INSERT INTO portfolio (id, title, type, price, status, location, date, review, photo, photos) VALUES
('pt01','บ้านเดี่ยวหรู สุขุมวิท 71 ปิดดีลสำเร็จ','บ้านเดี่ยว',16500000,'SOLD','สุขุมวิท 71 กรุงเทพฯ','ม.ค. 2569',
 'ทีม Matchdoor ช่วยขายได้ภายใน 3 สัปดาห์ ราคาเกินเป้าที่ตั้งไว้ ประทับใจมาก ดูแลดีตั้งแต่ถ่ายรูปจนถึงวันโอน ทำเอกสารให้ทุกอย่าง ไม่ต้องยุ่งยากเลย',
 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=400',
 ARRAY['https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800']),

('pt02','คอนโด Riverside วิวแม่น้ำ โอนสำเร็จ','คอนโด',8800000,'SOLD','เจริญนคร กรุงเทพฯ','ก.พ. 2569',
 'หาผู้ซื้อได้ภายใน 45 วัน ราคาดีมาก ทีมงานช่วยเรื่องเอกสารทั้งหมด ไม่ต้องยุ่งยากเลย ขอบคุณพี่ศิริพรมากๆ ครับ',
 'https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=400',
 ARRAY['https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800']),

('pt03','วิลล่าภูเก็ต ปล่อยเช่าระยะยาว','วิลล่า',95000,'RENTED','บางเทา ภูเก็ต','มี.ค. 2569',
 'ได้ผู้เช่าชาวต่างชาติ 12 เดือน รายได้มั่นคง Matchdoor คัดผู้เช่าคุณภาพดีให้เลย ไม่มีปัญหา ตรวจสอบประวัติให้ครบ แนะนำเลยครับ',
 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=400',
 ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800','https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800']),

('pt04','ที่ดิน EEC ชลบุรี ปิดดีลนักลงทุน','ที่ดิน',22000000,'SOLD','ศรีราชา ชลบุรี','เม.ย. 2569',
 'ขายได้ราคาดีกว่าตลาด 12% ใช้เวลาแค่ 2 เดือน ทีมงานมีฐานข้อมูลนักลงทุนดีมาก ติดต่อนักลงทุนญี่ปุ่นให้ได้เลย แนะนำเลย',
 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400',
 ARRAY['https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800','https://images.unsplash.com/photo-1592595896616-c37162298647?w=800']),

('pt05','ทาวน์โฮม แจ้งวัฒนะ ปล่อยเช่าสำเร็จ','ทาวน์โฮม',20000,'RENTED','แจ้งวัฒนะ นนทบุรี','พ.ค. 2569',
 'ได้ผู้เช่าภายใน 1 สัปดาห์ เป็นพนักงานบริษัทใหญ่ ทีม Matchdoor ช่วยตรวจสอบประวัติผู้เช่าให้ด้วย ดีมากครับ ไม่มีปัญหาเลย',
 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400',
 ARRAY['https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800']),

('pt06','คอนโด 2 ห้องนอน พระราม 9 โอนสำเร็จ','คอนโด',5200000,'SOLD','พระราม 9 กรุงเทพฯ','พ.ค. 2569',
 'ขายได้ราคาดีกว่าที่คาดไว้มาก ทีมงาน Matchdoor ช่วยตกแต่ง Staging ก่อนถ่ายรูป ส่งผลให้ได้ผู้ซื้อเร็วมาก ประทับใจบริการมาก',
 'https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=400',
 ARRAY['https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800']),

('pt07','วิลล่ากระบี่ ปิดดีลนักลงทุนต่างชาติ','วิลล่า',14500000,'SOLD','อ่าวนาง กระบี่','พ.ค. 2569',
 'ขายให้นักลงทุนชาวสิงคโปร์ได้ภายใน 60 วัน พี่ภาณุพงศ์มีฐานลูกค้าต่างชาติดีมาก ดำเนินเอกสารภาษาอังกฤษให้ครบถ้วน แนะนำสำหรับการขายอสังหาฯ ให้ชาวต่างชาติ',
 'https://images.unsplash.com/photo-1448630360428-65456885c650?w=400',
 ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800']),

('pt08','อาคารพาณิชย์ รัชดา ปล่อยเช่าต่อสัญญาใหม่','อาคารพาณิชย์',50000,'RENTED','รัชดาภิเษก กรุงเทพฯ','พ.ค. 2569',
 'ต่อสัญญาเช่าใหม่ได้ราคาขึ้น 15% จากเดิม ทีม Matchdoor ช่วยเจรจาและตรวจสอบสัญญาให้ครบถ้วน บริการครบจบ ไม่ต้องกังวลเลย',
 'https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=400',
 ARRAY['https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800'])

ON CONFLICT (id) DO UPDATE SET
  title=EXCLUDED.title, type=EXCLUDED.type, price=EXCLUDED.price, status=EXCLUDED.status,
  location=EXCLUDED.location, date=EXCLUDED.date, review=EXCLUDED.review,
  photo=EXCLUDED.photo, photos=EXCLUDED.photos;

-- ============================================================
-- 10. SEED: services (6 บริการ)
-- ============================================================
INSERT INTO services (id, name, icon, short_desc, full_desc, price, duration, sort_order) VALUES
('ac',   'ล้างแอร์',           'fa-wind',        'ล้างแอร์ทุกประเภท ราคาถูก',
 'บริการล้างแอร์ทุกยี่ห้อ ทั้งแบบแยกส่วน แบบตั้งพื้น และแบบฝังฝ้า ใช้น้ำยาคุณภาพสูง รับประกันงาน 30 วัน ไม่ทำลายคอยล์ ทีมช่างมีประสบการณ์กว่า 10 ปี บริการทั่วกรุงเทพฯ และปริมณฑล',
 '450 บาท/ตัว','1-2 ชั่วโมง',1),

('maid','แม่บ้านมืออาชีพ',    'fa-broom',       'แม่บ้านผ่านการอบรมและตรวจสอบประวัติ',
 'บริการแม่บ้านมืออาชีพ ผ่านการอบรมมาตรฐาน และตรวจสอบประวัติอาชญากรรมทุกคน มีประกันภัยการทำงาน บริการรายวัน รายสัปดาห์ และรายเดือน ยืดหยุ่นตามความต้องการ',
 '600 บาท/วัน','ตามตกลง',2),

('furn','ซ่อมเฟอร์นิเจอร์',   'fa-couch',       'ซ่อมและดัดแปลงเฟอร์นิเจอร์ทุกชนิด',
 'ซ่อมเฟอร์นิเจอร์ทุกประเภท ทั้งไม้จริง MDF และโลหะ รวมถึง Built-in เปลี่ยนบานพับ ลูกล้อ หัวเตียง งานเคลือบผิวใหม่ และงาน Custom สั่งทำพิเศษ มีตัวอย่างผลงานให้ชม',
 '350 บาท+','1-4 ชั่วโมง',3),

('plumb','ซ่อมระบบประปา',      'fa-wrench',      'แก้ไขท่อรั่ว อุดตัน ทุกปัญหา',
 'ซ่อมท่อรั่ว แก้อุดตัน เปลี่ยนวาล์ว ซ่อมฝักบัว ติดตั้งระบบประปาใหม่ ช่างมีใบรับรอง รับประกันงาน 90 วัน ออกเดินทางทั่วกรุงเทพฯ และปริมณฑล ฉุกเฉิน 24 ชั่วโมง',
 '500 บาท+','1-3 ชั่วโมง',4),

('elec','งานไฟฟ้าภายในบ้าน',   'fa-bolt',        'ช่างไฟฟ้ามีใบอนุญาต ปลอดภัย 100%',
 'ซ่อมและติดตั้งระบบไฟฟ้าภายในบ้าน เดินสายไฟใหม่ เปลี่ยนสวิตช์ ปลั๊ก ตู้ MDB ระบบกราวด์ ไฟส่องสว่าง LED ช่างไฟฟ้ามีใบอนุญาต กฟน./กปภ. รับรองทุกคน',
 '500 บาท+','1-4 ชั่วโมง',5),

('paint','ทาสีภายนอก-ภายใน',   'fa-paint-roller','ทาสีบ้านทุกขนาด ราคายุติธรรม',
 'รับทาสีบ้านทั้งภายในและภายนอก ใช้สีคุณภาพสูง ไม่ซีด ไม่ลอก มีระบบกันราและกันน้ำ ช่างประสบการณ์ มีผลงานอ้างอิงให้ชมได้ รับงานทั่วกรุงเทพฯ และปริมณฑล',
 '35 บาท/ตร.ม.+','ตามขนาดงาน',6)

ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, icon=EXCLUDED.icon, short_desc=EXCLUDED.short_desc,
  full_desc=EXCLUDED.full_desc, price=EXCLUDED.price, duration=EXCLUDED.duration,
  sort_order=EXCLUDED.sort_order;

-- ============================================================
-- 11. SEED: blogs (5 บทความ)
-- ============================================================
INSERT INTO blogs (title, cat, date, icon, color, content, photos, sort_order, is_published) VALUES
('EEC โอกาสทองอสังหาฯ ภาคตะวันออก 2569','การลงทุน','10 เม.ย. 2569','🏆',
 'linear-gradient(135deg,#667eea,#764ba2)',
 '<p>เขตพัฒนาพิเศษภาคตะวันออก (EEC) ยังคงเป็นแม่เหล็กดึงดูดการลงทุนทั้งในและต่างประเทศในปี 2569 นี้ โดยเฉพาะในจังหวัดชลบุรี ระยอง และฉะเชิงเทรา</p><h3>ทำเลที่น่าจับตา</h3><ul><li><strong>ศรีราชา-แหลมฉบัง</strong>: ใกล้ท่าเรือ ราคาที่ดินยังไม่พุ่งสูงสุด</li><li><strong>บ้านบึง</strong>: รถไฟความเร็วสูงสายใหม่ผ่าน ราคาที่ดินยังถูก</li><li><strong>มาบตาพุด</strong>: นิคมพลังงานสะอาด ความต้องการที่พักพุ่งสูง</li><li><strong>อู่ตะเภา</strong>: สนามบินนานาชาติแห่งใหม่ โอกาสโรงแรมสูงมาก</li></ul><p>คาดการณ์ว่าราคาที่ดินในโซน EEC จะเพิ่มขึ้น 15-25% ในช่วง 3 ปีข้างหน้า ตามโครงการรถไฟความเร็วสูงและสนามบินอู่ตะเภา</p>',
 ARRAY['https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800','https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800'],1,TRUE),

('คอนโดแบบไหนคุ้มค่ากว่าในยุคดอกเบี้ยสูง','คำแนะนำ','5 เม.ย. 2569','🏦',
 'linear-gradient(135deg,#f093fb,#f5576c)',
 '<p>ในยุคที่อัตราดอกเบี้ยเงินกู้ยังทรงตัวสูง การเลือกซื้อคอนโดให้คุ้มค่าต้องคิดละเอียดกว่าเดิม</p><h3>สูตรคำนวณง่ายๆ</h3><ul><li><strong>Gross Yield</strong>: ค่าเช่าต่อปี / ราคาซื้อ × 100 ควรเกิน 5%</li><li><strong>Net Yield</strong>: หักค่าส่วนกลาง ค่าซ่อม และภาษี ควรเกิน 3%</li><li><strong>Capital Gain</strong>: ทำเลใกล้ BTS/MRT มักขึ้นราคา 5-8% ต่อปี</li></ul><h3>ข้อควรระวัง</h3><ul><li>ค่าส่วนกลางต่อปีบางโครงการสูงถึง 80,000-120,000 บาท</li><li>คอนโดอายุเกิน 15 ปี ค่าซ่อมแซมสูง ควรตรวจสอบสภาพ</li><li>ผู้ซื้อใหม่ควรถือนานอย่างน้อย 5 ปีถึงจะคุ้มทุน</li></ul>',
 ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800','https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800'],2,TRUE),

('วิธีเตรียมบ้านให้ขายได้ไวที่สุด','เคล็ดลับ','28 มี.ค. 2569','🏠',
 'linear-gradient(135deg,#43e97b,#38f9d7)',
 '<p>บ้านที่เตรียมพร้อมก่อนขายจะขายได้เร็วกว่าและได้ราคาสูงกว่าค่าเฉลี่ย 8-15% ทำตาม 5 ขั้นตอนนี้</p><ol><li><strong>Deep Clean ทั้งหลัง</strong>: รวมถึงฝ้าเพดาน มุมห้องน้ำ และระเบียง</li><li><strong>ซ่อมแซมจุดเล็กน้อย</strong>: ก๊อกน้ำหยด ประตูกีดขวาง ปลั๊กไฟหลวม</li><li><strong>ทาสีใหม่</strong>: ใช้สีขาวหรือครีม เปิดโปร่ง ดูสะอาด</li><li><strong>Home Staging</strong>: จัดเฟอร์นิเจอร์ใหม่ ใส่ต้นไม้ ดอกไม้สด</li><li><strong>ถ่ายรูปมืออาชีพ</strong>: รูปดีเพิ่มโอกาสผู้สนใจได้ 3 เท่า</li></ol><p>การลงทุนซ่อมแซมบ้านก่อนขาย 30,000-80,000 บาท มักได้ราคาคืนกลับมา 200,000-500,000 บาทเลยทีเดียว</p>',
 ARRAY['https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800'],3,TRUE),

('PDPA กับการซื้อขายอสังหาฯ ที่นายหน้าต้องรู้','สาระน่ารู้','20 มี.ค. 2569','📋',
 'linear-gradient(135deg,#4facfe,#00f2fe)',
 '<p>พระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล (PDPA) ส่งผลกระทบโดยตรงต่อธุรกิจนายหน้าอสังหาฯ ที่ต้องเก็บข้อมูลลูกค้า</p><h3>สิ่งที่นายหน้าต้องทำ</h3><ul><li><strong>ขอความยินยอม</strong>: ก่อนเก็บข้อมูลส่วนบุคคล ต้องขอ consent เป็นลายลักษณ์อักษร</li><li><strong>แจ้งวัตถุประสงค์</strong>: บอกชัดว่าเก็บข้อมูลไปทำอะไร</li><li><strong>ห้ามเก็บเกินความจำเป็น</strong>: เก็บเฉพาะที่ต้องการจริงๆ</li><li><strong>มีระบบลบข้อมูล</strong>: ลูกค้าขอให้ลบได้ทุกเมื่อ</li></ul><p>โทษปรับสูงสุด 5 ล้านบาท และอาจมีโทษอาญาเพิ่มเติม แนะนำให้ปรึกษาทนายก่อนสร้างระบบ CRM ใหม่</p>',
 ARRAY['https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800','https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800'],4,TRUE),

('เปรียบเทียบทำเล: กรุงเทพฯ vs เมืองรอง ลงทุนอะไรดีกว่า','การลงทุน','12 มี.ค. 2569','🔍',
 'linear-gradient(135deg,#fa709a,#fee140)',
 '<p>นักลงทุนรุ่นใหม่หลายคนมองข้ามเมืองรองที่มีศักยภาพสูง ลองเปรียบกันดู</p><table border="0" cellpadding="8" style="width:100%;border-collapse:collapse;font-size:13px"><tr style="background:#f0eeff"><th>เมือง</th><th>Gross Yield เช่า</th><th>Capital Gain/ปี</th><th>สภาพคล่อง</th></tr><tr><td>กรุงเทพฯ ใจกลาง</td><td>4-5%</td><td>5-8%</td><td>สูง</td></tr><tr><td>ภูเก็ต</td><td>7-10%</td><td>6-10%</td><td>ปานกลาง</td></tr><tr><td>เชียงใหม่</td><td>6-8%</td><td>4-6%</td><td>ปานกลาง</td></tr><tr><td>พัทยา-ชลบุรี</td><td>6-9%</td><td>5-8%</td><td>ปานกลาง</td></tr></table><p>สรุป: ถ้าต้องการสภาพคล่องสูงเลือกกรุงเทพฯ แต่ถ้าต้องการ Yield สูงกว่า ภูเก็ตและพัทยาน่าสนใจกว่า</p>',
 ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1582407947304-fd86f028f716?w=800'],5,TRUE)

ON CONFLICT DO NOTHING;

-- ============================================================
-- 12. SEED: site_config
-- ============================================================
INSERT INTO site_config (id, addr, phone, line_id, fb_url, hero_sub, srv_title, srv_sub, yt_url, copyright)
VALUES (1,
  '88/8 อาคารแมทช์ดอร์ ชั้น 12 ถนนสุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
  '061-888-9999','@matchdoor','https://facebook.com/matchdoor.official',
  'อสังหาฯ ครบทุกทำเล ทุกประเภท บ้าน คอนโด ที่ดิน วิลล่า ราคาดีที่สุด',
  'บริการครบจบทุกขั้นตอน',
  'ซื้อ ขาย เช่า อสังหาฯ ปรึกษาเราได้ทุกเวลา ฟรี ไม่มีค่าใช้จ่าย',
  'https://www.youtube.com/embed/VUQfT3gNT3g?si=WDXL3fAOPfFaeVFb',
  '© 2569 Matchdoor — สงวนลิขสิทธิ์')
ON CONFLICT (id) DO UPDATE SET
  addr=EXCLUDED.addr, phone=EXCLUDED.phone, line_id=EXCLUDED.line_id,
  fb_url=EXCLUDED.fb_url, hero_sub=EXCLUDED.hero_sub, srv_title=EXCLUDED.srv_title,
  srv_sub=EXCLUDED.srv_sub, yt_url=EXCLUDED.yt_url, copyright=EXCLUDED.copyright,
  updated_at=NOW();

-- ============================================================
-- 13. SEED: legal_pages (5 หน้า)
-- ============================================================
INSERT INTO legal_pages (id, title, content, version, effective_date) VALUES
('privacy','นโยบายความเป็นส่วนตัว (Privacy Policy)',
 '<div class="highlight-box" style="margin-bottom:16px"><strong>บังคับใช้ตาม:</strong> พ.ร.บ.คุ้มครองข้อมูลส่วนบุคคล (PDPA) พ.ศ. 2562</div><h3>1. ข้อมูลที่เราเก็บรวบรวม</h3><p>ชื่อ-นามสกุล เบอร์โทรศัพท์ อีเมล Line ID รายละเอียดความต้องการอสังหาริมทรัพย์ และข้อมูลที่เก็บอัตโนมัติ เช่น IP Address, cookies, ข้อมูลการใช้งานเว็บไซต์</p><h3>2. วัตถุประสงค์การใช้ข้อมูล</h3><p>เพื่อให้บริการซื้อ-ขาย-เช่าอสังหาริมทรัพย์ ติดต่อกลับลูกค้า วิเคราะห์เพื่อพัฒนาบริการ จับคู่ทรัพย์กับความต้องการ และปฏิบัติตามกฎหมาย</p><h3>3. การเปิดเผยข้อมูล</h3><p>เราไม่ขายข้อมูลส่วนบุคคลของคุณให้บุคคลที่สาม อาจแบ่งปันกับตัวแทนในเครือข่าย Matchdoor เพื่อให้บริการเท่านั้น</p><h3>4. สิทธิ์ของท่าน</h3><p>ท่านมีสิทธิ์เข้าถึง แก้ไข ลบ หรือขอสำเนาข้อมูลส่วนบุคคลของตนเองได้ตลอดเวลา ติดต่อ: privacy@matchdoor.co.th</p><div class="highlight-box"><strong>📧 ติดต่อ DPO:</strong> privacy@matchdoor.co.th | <strong>📞 โทร:</strong> 061-888-9999</div>',
 '2.1','2026-01-01'),

('terms','ข้อกำหนดการใช้งาน (Terms of Service)',
 '<div class="highlight-box" style="margin-bottom:16px"><strong>กรุณาอ่านข้อกำหนดนี้ก่อนใช้งาน Matchdoor</strong></div><h3>1. การยอมรับข้อกำหนด</h3><p>การใช้งานแพลตฟอร์ม Matchdoor ถือว่าท่านยอมรับข้อกำหนดและเงื่อนไขทั้งหมดนี้ครบถ้วน</p><h3>2. บัญชีผู้ใช้</h3><p>ท่านต้องให้ข้อมูลที่ถูกต้องครบถ้วน และรับผิดชอบต่อกิจกรรมทั้งหมดที่เกิดขึ้นภายใต้บัญชีของท่าน</p><h3>3. การใช้งานที่ยอมรับได้</h3><p>ห้ามโพสต์ข้อมูลเท็จ ฉ้อโกง ราคาผิดพลาด หรือเนื้อหาที่ผิดกฎหมายทุกประเภท</p><h3>4. ทรัพย์สินทางปัญญา</h3><p>เนื้อหา โลโก้ และรูปแบบเว็บไซต์ Matchdoor เป็นลิขสิทธิ์ของบริษัท ห้ามนำไปใช้โดยไม่ได้รับอนุญาต</p><h3>5. การระงับบัญชี</h3><p>Matchdoor ขอสงวนสิทธิ์ระงับบัญชีที่ละเมิดข้อกำหนดโดยไม่ต้องแจ้งล่วงหน้า</p><div class="highlight-box"><strong>📧 ฝ่ายกฎหมาย:</strong> legal@matchdoor.co.th</div>',
 '2.1','2026-01-01'),

('acceptable_use','นโยบายการใช้งานที่ยอมรับได้',
 '<div class="highlight-box" style="margin-bottom:16px">Matchdoor มุ่งมั่นสร้างแพลตฟอร์มที่ปลอดภัยและน่าเชื่อถือ</div><h3>สิ่งที่อนุญาต</h3><ul><li>โพสต์ทรัพย์สินที่คุณมีสิทธิ์ขายหรือเช่าจริง</li><li>ให้ข้อมูลราคาที่ถูกต้องและเป็นปัจจุบัน</li><li>ใช้รูปภาพจริงของทรัพย์ที่ลงประกาศ</li></ul><h3>สิ่งที่ห้ามทำ</h3><ul><li>โพสต์ทรัพย์ที่ไม่มีอยู่จริงหรือขายไปแล้ว</li><li>ใช้ราคาล่อลวงที่ต่างจากความเป็นจริง</li><li>ก็อปปี้รูปภาพจากประกาศอื่นโดยไม่ได้รับอนุญาต</li><li>ส่งข้อความสแปมหรือโฆษณาที่ไม่เกี่ยวข้อง</li></ul><p>การฝ่าฝืนอาจส่งผลให้บัญชีถูกระงับและดำเนินการทางกฎหมาย</p>',
 '1.2','2026-01-01'),

('buy_sell','ข้อตกลงการซื้อขาย/เช่า',
 '<div class="highlight-box" style="margin-bottom:16px">Matchdoor เป็นแพลตฟอร์มตัวกลาง ไม่ใช่คู่สัญญาในการซื้อขาย</div><h3>หน้าที่ของ Matchdoor</h3><ul><li>เชื่อมต่อผู้ซื้อและผู้ขาย/เจ้าของทรัพย์</li><li>ตรวจสอบข้อมูลทรัพย์เบื้องต้น</li><li>ให้คำปรึกษาและอำนวยความสะดวก</li></ul><h3>หน้าที่ของผู้ใช้</h3><ul><li>ตรวจสอบโฉนดที่ดินและเอกสารสิทธิ์ด้วยตนเอง</li><li>ทำสัญญาซื้อขายตามกฎหมายที่เกี่ยวข้อง</li><li>ชำระภาษีและค่าธรรมเนียมตามกฎหมาย</li></ul><p>Matchdoor ไม่รับประกันความถูกต้องของข้อมูลที่เจ้าของทรัพย์ให้ ผู้ซื้อควรตรวจสอบโฉนดด้วยตนเองก่อนโอนทุกครั้ง</p><div class="highlight-box"><strong>📞 ฝ่ายกฎหมาย:</strong> legal@matchdoor.co.th | <strong>📞 Call Center:</strong> 061-888-9999</div>',
 '2.1','2026-01-01'),

('cookie','นโยบายคุกกี้ (Cookie Policy)',
 '<div class="highlight-box" style="margin-bottom:16px">เว็บไซต์ Matchdoor ใช้คุกกี้เพื่อพัฒนาประสบการณ์ของท่าน</div><h3>คุกกี้ที่จำเป็น (Strictly Necessary)</h3><p>ใช้สำหรับการทำงานพื้นฐาน เช่น การล็อกอิน รายการโปรด การค้นหา และการแสดงผลที่ถูกต้อง ไม่สามารถปิดได้</p><h3>คุกกี้วิเคราะห์ (Analytics)</h3><p>ช่วยให้เราเข้าใจพฤติกรรมการใช้งาน เช่น หน้าที่ถูกเข้าชมมากที่สุด เพื่อนำไปพัฒนาบริการ ท่านสามารถปฏิเสธได้</p><h3>คุกกี้การตลาด (Marketing)</h3><p>ใช้แสดงโฆษณาที่เกี่ยวข้องกับความสนใจของท่าน สามารถปิดได้ผ่านการตั้งค่าคุกกี้</p><h3>การจัดการคุกกี้</h3><p>ท่านสามารถตั้งค่าคุกกี้ได้ผ่านแบนเนอร์ที่ด้านล่างหน้าจอ หรือในการตั้งค่าเบราว์เซอร์ของท่านได้ตลอดเวลา</p><div class="highlight-box"><strong>📧 ติดต่อ:</strong> privacy@matchdoor.co.th</div>',
 '1.1','2026-01-01')

ON CONFLICT (id) DO UPDATE SET
  title=EXCLUDED.title, content=EXCLUDED.content, version=EXCLUDED.version,
  effective_date=EXCLUDED.effective_date, updated_at=NOW();

-- ============================================================
-- 14. VIEWS (ใช้ใน index.html + admin)
-- ============================================================

-- properties พร้อมข้อมูล agent (JOIN สำเร็จรูป)
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

-- สรุปภาพรวม dashboard (admin) — อัปเดตตัวเลขใหม่
DROP VIEW IF EXISTS v_dashboard_summary;
CREATE VIEW v_dashboard_summary AS
SELECT
  (SELECT COUNT(*) FROM properties)                              AS total_properties,
  (SELECT COUNT(*) FROM properties WHERE tx      = 'BUY')       AS for_sale,
  (SELECT COUNT(*) FROM properties WHERE tx      = 'RENT')      AS for_rent,
  (SELECT COUNT(*) FROM properties WHERE is_new  = TRUE)        AS new_listings,
  (SELECT COUNT(*) FROM properties WHERE is_rec  = TRUE)        AS recommended,
  (SELECT COUNT(*) FROM agents     WHERE is_active = TRUE)      AS total_agents,
  (SELECT COUNT(*) FROM portfolio)                              AS total_deals,
  (SELECT COUNT(*) FROM portfolio  WHERE status  = 'SOLD')      AS sold_count,
  (SELECT COUNT(*) FROM portfolio  WHERE status  = 'RENTED')    AS rented_count,
  (SELECT COUNT(*) FROM listings   WHERE status  = 'รอตรวจสอบ') AS pending_listings,
  (SELECT COUNT(*) FROM buy_requests WHERE status = 'ใหม่')     AS new_requests;

-- ============================================================
-- 15. FUNCTION: search_properties_full (รองรับ 45 รายการ)
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
  SELECT * FROM properties
  WHERE
    (p_tx       = '' OR tx::TEXT     = p_tx)
    AND (p_type = '' OR type::TEXT   = p_type)
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
-- 16. STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES
  ('property-images', 'property-images', TRUE),
  ('agent-avatars',   'agent-avatars',   TRUE),
  ('blog-images',     'blog-images',     TRUE)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "public_read_property_images" ON storage.objects;
CREATE POLICY "public_read_property_images" ON storage.objects FOR SELECT USING (bucket_id = 'property-images');

DROP POLICY IF EXISTS "public_read_agent_avatars"   ON storage.objects;
CREATE POLICY "public_read_agent_avatars"   ON storage.objects FOR SELECT USING (bucket_id = 'agent-avatars');

DROP POLICY IF EXISTS "public_read_blog_images"     ON storage.objects;
CREATE POLICY "public_read_blog_images"     ON storage.objects FOR SELECT USING (bucket_id = 'blog-images');

DROP POLICY IF EXISTS "auth_upload_property_images" ON storage.objects;
CREATE POLICY "auth_upload_property_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'property-images' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "auth_upload_blog_images"     ON storage.objects;
CREATE POLICY "auth_upload_blog_images"     ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'blog-images'     AND auth.role() = 'authenticated');


-- ============================================================
-- MATCHDOOR — SQL Patch: เพิ่ม properties 50 รายการ (p46–p95)
-- Version : 9.1 patch
-- Updated : 2026 (พฤษภาคม)
-- วิธีใช้ : วางต่อจาก Database_v9.sql หรือรันแยกใน Supabase SQL Editor
--           หลังจาก v9.0 รันเรียบร้อยแล้ว
-- ============================================================

INSERT INTO properties
  (id, title, type, province, location, price, tx, bed, bath, area, land_area,
   floors, floor_no, parking, furniture, pets_allowed, appliances,
   is_new, is_rec, description, agent_id, photos, created_at)
VALUES

-- ══════════════════════════════════════════════════════════════
-- บ้านเดี่ยว (p46–p54)
-- ══════════════════════════════════════════════════════════════
('p46','บ้านเดี่ยว 2 ชั้น Pool Villa ใจกลางพัทยา','บ้านเดี่ยว','ชลบุรี','พัทยาเหนือ ชลบุรี',
 12500000,'BUY',4,4,320,100,2,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','โฮมเธียเตอร์'],TRUE,TRUE,
 'บ้านเดี่ยวสไตล์ Tropical Resort ใจกลางพัทยาเหนือ สระว่ายน้ำส่วนตัวยาว 10 เมตร สวนปาล์มร่มรื่น ห้องนอนใหญ่ 4 ห้อง ล้วนมีห้องน้ำในตัว ครัวยุโรป Built-in เต็มรูปแบบ ระบบ Smart Home ปั้มน้ำอัตโนมัติ ปลอดภัย 24 ชั่วโมง ใกล้เซ็นทรัล พัทยา 5 นาที',
 'a5',ARRAY['https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800','https://images.unsplash.com/photo-1560184897-ae75f418493e?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800'],
 '2026-05-01'),

('p47','บ้านเดี่ยวให้เช่า หรู ย่านสุขุมวิท 49','บ้านเดี่ยว','กรุงเทพฯ','สุขุมวิท 49 ทองหล่อ กรุงเทพฯ',
 85000,'RENT',4,4,380,80,2,0,3,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม','ทีวี'],TRUE,TRUE,
 'บ้านเดี่ยวหรู 2 ชั้น ให้เช่า สไตล์ Modern Luxury ย่านทองหล่อ เฟอร์นิเจอร์ครบ Built-in ทั้งหลัง สระว่ายน้ำส่วนตัว สวนส่วนตัว ที่จอดรถ 3 คัน ใกล้ BTS ทองหล่อ 700 เมตร เหมาะ Expat ครอบครัวใหญ่ และผู้บริหารระดับสูง',
 'a1',ARRAY['https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800','https://images.unsplash.com/photo-1613545325278-f24b0cae1224?w=800','https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800'],
 '2026-05-02'),

('p48','บ้านเดี่ยว 2 ชั้น โครงการใหม่ อุดรธานี','บ้านเดี่ยว','อุดรธานี','เมือง อุดรธานี',
 2650000,'BUY',3,2,140,60,2,0,2,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'บ้านเดี่ยวใหม่ 2 ชั้น โครงการสิรีลักษณ์ อุดรธานี 3 ห้องนอน 2 ห้องน้ำ พื้นที่ใช้สอย 140 ตร.ม. บนที่ดิน 60 ตร.วา ใกล้ห้างเซ็นทรัล อุดรธานี มหาวิทยาลัยราชภัฏอุดรธานี ดอกเบี้ย 0% 3 ปีแรก พร้อมอยู่',
 'a4',ARRAY['https://images.unsplash.com/photo-1543071220-6ee5bf71a54e?w=800','https://images.unsplash.com/photo-1505118380757-91f5f5632de0?w=800','https://images.unsplash.com/photo-1572120360610-d971b9d7767c?w=800','https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800'],
 '2026-05-03'),

('p49','บ้านเดี่ยวริมทะเล หัวหิน วิวพาโนราม่า','บ้านเดี่ยว','ประจวบคีรีขันธ์','หัวหิน ประจวบคีรีขันธ์',
 28000000,'BUY',5,5,480,200,2,0,4,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','โฮมเธียเตอร์','สมาร์ทโฮม'],FALSE,TRUE,
 'บ้านเดี่ยวริมทะเลหัวหิน 2 ชั้น บนที่ดิน 200 ตร.วา วิวอ่าวหัวหินพาโนราม่า 5 ห้องนอน สระว่ายน้ำส่วนตัวริมชายหาด ห้องนั่งเล่น Double Volume ระเบียงวิวทะเล ครัว Chef Kitchen ระบบ Smart Home เต็มรูปแบบ เหมาะ Holiday Home และปล่อยเช่า Premium',
 'a3',ARRAY['https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1598994942340-0a2e0e11c5bc?w=800','https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1502672023488-70e25813eb80?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800'],
 '2026-05-04'),

('p50','บ้านเดี่ยว 3 ชั้น Modern Style บางนา-วงแหวน','บ้านเดี่ยว','กรุงเทพฯ','บางนา-ตราด กม.7 กรุงเทพฯ',
 7800000,'BUY',4,4,280,65,3,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ไมโครเวฟ'],TRUE,TRUE,
 'บ้านเดี่ยว 3 ชั้น สไตล์ Modern Minimalist ย่านบางนา 4 ห้องนอน 4 ห้องน้ำ พื้นที่ใช้สอย 280 ตร.ม. ห้อง Master Bedroom ขนาดใหญ่ Walk-in Closet ห้องทำงาน ห้องออกกำลังกาย ใกล้ Mega Bangna และสนามบินสุวรรณภูมิ 15 นาที',
 'a1',ARRAY['https://images.unsplash.com/photo-1604328698692-f76ea9498e76?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800','https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800','https://images.unsplash.com/photo-1565402170291-8491f14678db?w=800','https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800'],
 '2026-05-05'),

('p51','บ้านเดี่ยวสไตล์ Japanese Zen เขาใหญ่','บ้านเดี่ยว','นครราชสีมา','ปากช่อง เขาใหญ่ นครราชสีมา',
 9500000,'BUY',3,3,280,250,1,0,3,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เตาผิง'],TRUE,TRUE,
 'บ้านเดี่ยวชั้นเดียวสไตล์ Japanese Zen บนที่ดิน 250 ตร.วา อากาศเย็นสบายตลอดปี สวนหินญี่ปุ่น บ่อน้ำ ซาวน่า สระน้ำร้อนกลางแจ้ง 3 ห้องนอน ล้วนมีห้องน้ำในตัว วิวภูเขา รับสัตว์เลี้ยง ใกล้อุทยานฯ เขาใหญ่',
 'a6',ARRAY['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800','https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800','https://images.unsplash.com/photo-1484301548518-d0e0a5db0fc8?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-05-06'),

('p52','บ้านเดี่ยว 2 ชั้น โครงการ LPN ลาดกระบัง','บ้านเดี่ยว','กรุงเทพฯ','ลาดกระบัง กรุงเทพฯ',
 3800000,'BUY',3,2,150,50,2,0,2,'none',FALSE,
 ARRAY['แอร์'],FALSE,FALSE,
 'บ้านเดี่ยว 2 ชั้น โครงการ LPN Village ลาดกระบัง 3 ห้องนอน 2 ห้องน้ำ ราคาจับต้องได้ ใกล้สนามบินสุวรรณภูมิ 20 นาที สถาบันเทคโนโลยีพระจอมเกล้าลาดกระบัง เหมาะครอบครัวรุ่นใหม่ที่มีงบจำกัด',
 'a4',ARRAY['https://images.unsplash.com/photo-1602343168117-bb8ffe3e2e9f?w=800','https://images.unsplash.com/photo-1628624747186-a941c476b7ef?w=800','https://images.unsplash.com/photo-1516253593875-b1baa8b4a609?w=800','https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800','https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?w=800'],
 '2026-05-07'),

('p53','บ้านเดี่ยวให้เช่า ย่านรามอินทรา มีนบุรี','บ้านเดี่ยว','กรุงเทพฯ','รามอินทรา-มีนบุรี กรุงเทพฯ',
 25000,'RENT',3,2,180,65,2,0,2,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,FALSE,
 'บ้านเดี่ยว 2 ชั้น ให้เช่า ย่านรามอินทรา เฟอร์นิเจอร์ครบ 3 ห้องนอน 2 ห้องน้ำ สวนหน้าบ้าน ที่จอดรถ 2 คัน รับสัตว์เลี้ยง ใกล้ Lotus มีนบุรี โรงพยาบาลนวมินทร์ เหมาะครอบครัวที่ต้องการพื้นที่กว้าง',
 'a4',ARRAY['https://images.unsplash.com/photo-1439792675105-701e6a4ab6f0?w=800','https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800','https://images.unsplash.com/photo-1484154218962-a197022b6967?w=800','https://images.unsplash.com/photo-1516455207474-a4887912729c?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800'],
 '2026-05-08'),

('p54','บ้านเดี่ยว 2 ชั้น Modern Tropical ภูเก็ต','บ้านเดี่ยว','ภูเก็ต','กะตะ ภูเก็ต',
 15800000,'BUY',4,4,350,160,2,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'บ้านเดี่ยวสไตล์ Modern Tropical ย่านกะตะ ภูเก็ต ห่างชายหาดกะตะ 800 เมตร สระว่ายน้ำส่วนตัว สวนเขตร้อน 4 ห้องนอน Master Suite ชั้น 2 ระเบียงวิวสระ เหมาะ Holiday Home และลงทุนปล่อยเช่า คาด Yield 7-9%',
 'a3',ARRAY['https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800','https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1610641818989-c2051b5e2cfd?w=800'],
 '2026-05-09'),

-- ══════════════════════════════════════════════════════════════
-- คอนโด (p55–p66)
-- ══════════════════════════════════════════════════════════════
('p55','คอนโด 1 ห้องนอน ใกล้ BTS สยาม ราคาดีมาก','คอนโด','กรุงเทพฯ','สยาม-ปทุมวัน กรุงเทพฯ',
 5200000,'BUY',1,1,46,0,0,15,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโด 1 ห้องนอน ชั้น 15 ตกแต่ง Built-in Luxury สไตล์ Urban Chic ใกล้ BTS สยาม 400 เมตร วิวเมือง สระว่ายน้ำ Rooftop ฟิตเนส Lounge Bar Sky Deck เหมาะมนุษย์เงินเดือนและนักลงทุน',
 'a2',ARRAY['https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=800','https://images.unsplash.com/photo-1619994403073-2cec844b8e63?w=800','https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800','https://images.unsplash.com/photo-1600210492493-0946911123ea?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],
 '2026-05-10'),

('p56','คอนโดให้เช่า สตูดิโอ ใกล้ BTS อ่อนนุช','คอนโด','กรุงเทพฯ','อ่อนนุช สุขุมวิท กรุงเทพฯ',
 14000,'RENT',0,1,28,0,0,7,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี'],FALSE,FALSE,
 'คอนโดสตูดิโอ ให้เช่า เฟอร์นิเจอร์ครบ ชั้น 7 ใกล้ BTS อ่อนนุช 300 เมตร อินเตอร์เน็ต Fiber รวม รักษาความปลอดภัย 24 ชั่วโมง เหมาะนักศึกษา มนุษย์เงินเดือน ราคาประหยัด',
 'a2',ARRAY['https://images.unsplash.com/photo-1614168092736-01bd2b8c8821?w=800','https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800','https://images.unsplash.com/photo-1562182384-08115de5ee97?w=800','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800'],
 '2026-05-11'),

('p57','คอนโด 2 ห้องนอน วิวสนามกีฬา ราชมังคลา','คอนโด','กรุงเทพฯ','รามคำแหง-บางกะปิ กรุงเทพฯ',
 3800000,'BUY',2,2,62,0,0,10,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,FALSE,
 'คอนโด 2 ห้องนอน ชั้น 10 วิวสนามกีฬาราชมังคลา ตกแต่ง Built-in ครบ ใกล้ MRT รามคำแหง ห้างแฟชั่น ไอส์แลนด์ มหาวิทยาลัยรามคำแหง ผลตอบแทนจากการเช่า 5.5-6% ต่อปี',
 'a2',ARRAY['https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800','https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800','https://images.unsplash.com/photo-1592595896616-c37162298647?w=800','https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800','https://images.unsplash.com/photo-1628744448840-55bdb2497bd4?w=800'],
 '2026-05-12'),

('p58','คอนโด Luxury วิวอ่าวไทย พัทยาใต้','คอนโด','ชลบุรี','พัทยาใต้ ชลบุรี',
 8900000,'BUY',2,2,85,0,0,20,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ไมโครเวฟ'],FALSE,TRUE,
 'คอนโด High-Rise ชั้น 20 วิวอ่าวไทย 180 องศา ย่านพัทยาใต้ ตกแต่ง Built-in สไตล์ Resort สระว่ายน้ำ Infinity ฟิตเนส Sky Lounge Rooftop Pool เหมาะลงทุน Holiday Rental Yield 8-10%',
 'a5',ARRAY['https://images.unsplash.com/photo-1540519338287-7c3f9a68ac3d?w=800','https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800','https://images.unsplash.com/photo-1565182999561-18d7dc61c393?w=800','https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800','https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?w=800'],
 '2026-05-13'),

('p59','คอนโดให้เช่า 2 ห้องนอน ย่านลาดพร้าว วังหิน','คอนโด','กรุงเทพฯ','ลาดพร้าว-วังหิน กรุงเทพฯ',
 28000,'RENT',2,1,55,0,0,12,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,FALSE,
 'คอนโด 2 ห้องนอน 1 ห้องน้ำ เฟอร์นิเจอร์ครบ ชั้น 12 วิวเมือง ใกล้ MRT วังหิน ห้าง The Mall บางกะปิ โรงพยาบาลสุขุมวิท เหมาะครอบครัวเล็กและคู่สมรส สัญญาขั้นต่ำ 12 เดือน',
 'a2',ARRAY['https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1582719508491-a3a1e6b7e0e0?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800','https://images.unsplash.com/photo-1560185008-b033106af5c3?w=800','https://images.unsplash.com/photo-1463453091185-61582044d556?w=800'],
 '2026-05-14'),

('p60','คอนโด 2 ห้องนอน ริมแม่น้ำ สาทร','คอนโด','กรุงเทพฯ','สาทร-เจริญราษฎร์ กรุงเทพฯ',
 11500000,'BUY',2,2,90,0,0,18,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'คอนโด 2 ห้องนอน ชั้น 18 วิวแม่น้ำเจ้าพระยา ย่านสาทร ตกแต่ง Full Luxury Built-in ระเบียงวิวแม่น้ำ ใกล้ BTS กรุงธนบุรี และ BTS สุรศักดิ์ Concierge ส่วนตัว สระว่ายน้ำ Sky Pool',
 'a2',ARRAY['https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1591474200742-8e512e6f98f8?w=800','https://images.unsplash.com/photo-1507089947368-19c1da9775ae?w=800','https://images.unsplash.com/photo-1534430480882-96c9102bcf71?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
 '2026-05-15'),

('p61','คอนโดใหม่ ใกล้ MRT สีม่วง นนทบุรี','คอนโด','นนทบุรี','เตาปูน-บางซ่อน นนทบุรี',
 2100000,'BUY',1,1,32,0,0,8,0,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น'],FALSE,FALSE,
 'คอนโดโลว์ไรส์ใหม่ 1 ห้องนอน ชั้น 8 ตกแต่งบางส่วน ใกล้ MRT สายสีม่วง เตาปูน ห้างเซ็นทรัล พลาซ่า ศรีราชา ราคาเริ่มต้น 2.1 ล้าน ผ่อนเพียง 8,000 บาท/เดือน ดาวน์ 10%',
 'a4',ARRAY['https://images.unsplash.com/photo-1617325247661-675ab4b64ae2?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800','https://images.unsplash.com/photo-1441986300927-91d9e4a5e1fc?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
 '2026-05-16'),

('p62','คอนโดให้เช่า วิวทะเล ป่าตอง ภูเก็ต','คอนโด','ภูเก็ต','ป่าตอง กะรน ภูเก็ต',
 45000,'RENT',2,2,68,0,0,12,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโด 2 ห้องนอน ชั้น 12 วิวทะเลอันดามัน ป่าตอง ภูเก็ต เฟอร์นิเจอร์ครบ ระเบียงส่วนตัว วิวพระอาทิตย์ตก สระว่ายน้ำ ฟิตเนส เหมาะ Long-Stay Expat และ Digital Nomad ปล่อยเช่าราย 3-6 เดือน',
 'a3',ARRAY['https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800'],
 '2026-05-17'),

('p63','คอนโด 3 ห้องนอน ย่านพระราม 4 ใกล้ MRT','คอนโด','กรุงเทพฯ','พระราม 4-คลองเตย กรุงเทพฯ',
 14800000,'BUY',3,3,135,0,0,22,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','ไมโครเวฟ'],FALSE,TRUE,
 'คอนโด 3 ห้องนอน ชั้น 22 ย่านพระราม 4 ตกแต่ง Luxury Built-in ทั้งห้อง ใกล้ MRT ลุมพินี ห้าง The Emporium และ EmQuartier ฟิตเนส สระว่ายน้ำ Co-working Space Rooftop Garden',
 'a2',ARRAY['https://images.unsplash.com/photo-1560448205-4d0b7db08ede?w=800','https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?w=800','https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=800','https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800','https://images.unsplash.com/photo-1556020685-ae41abfc9365?w=800'],
 '2026-05-18'),

('p64','คอนโดใหม่ ใกล้ BTS หมอชิต จตุจักร','คอนโด','กรุงเทพฯ','จตุจักร-หมอชิต กรุงเทพฯ',
 3500000,'BUY',1,1,35,0,0,10,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'คอนโดใหม่ 1 ห้องนอน ชั้น 10 ราคาพิเศษ Pre-Sale ใกล้ BTS หมอชิต และ MRT จตุจักร ตลาดนัดจตุจักร ตกแต่งบางส่วน ฟิตเนส สระว่ายน้ำ ลิฟต์ความเร็วสูง เหมาะลงทุนปล่อยเช่า',
 'a2',ARRAY['https://images.unsplash.com/photo-1619994403073-2cec844b8e63?w=800','https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800','https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800','https://images.unsplash.com/photo-1628744448840-55bdb2497bd4?w=800'],
 '2026-05-19'),

('p65','คอนโดให้เช่า 1 ห้องนอน ใกล้ ม.ธรรมศาสตร์ รังสิต','คอนโด','ปทุมธานี','คลองหลวง-รังสิต ปทุมธานี',
 7500,'RENT',1,1,26,0,0,4,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี'],FALSE,FALSE,
 'คอนโดให้เช่าราคาประหยัด 1 ห้องนอน ชั้น 4 เฟอร์นิเจอร์ครบ ใกล้มหาวิทยาลัยธรรมศาสตร์ รังสิต อินเตอร์เน็ต Fiber รวม ร้านสะดวกซื้อชั้นล่าง เหมาะนักศึกษา',
 'a4',ARRAY['https://images.unsplash.com/photo-1582719508491-a3a1e6b7e0e0?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800','https://images.unsplash.com/photo-1441986300927-91d9e4a5e1fc?w=800','https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800'],
 '2026-05-20'),

('p66','Penthouse 4 ห้องนอน วิวทะเล กะรน ภูเก็ต','คอนโด','ภูเก็ต','กะรน กะตะ ภูเก็ต',
 42000000,'BUY',4,4,380,0,0,35,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','โฮมเธียเตอร์','สมาร์ทโฮม'],FALSE,TRUE,
 'Penthouse หายากที่สุดในภูเก็ต ชั้น 35 วิวทะเลอันดามัน 360 องศา 4 ห้องนอน Duplex ระเบียงส่วนตัวขนาดใหญ่ ตกแต่งสไตล์ Ultra Luxury ครัว Chef-Grade ห้องน้ำหินอ่อน สระว่ายน้ำส่วนตัวบนดาดฟ้า Concierge ส่วนตัว',
 'a3',ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800'],
 '2026-05-21'),

-- ══════════════════════════════════════════════════════════════
-- ทาวน์โฮม (p67–p73)
-- ══════════════════════════════════════════════════════════════
('p67','ทาวน์โฮม 3 ชั้น หัวมุม ใกล้ BTS บางหว้า','ทาวน์โฮม','กรุงเทพฯ','บางหว้า-เพชรเกษม กรุงเทพฯ',
 5800000,'BUY',3,3,200,32,3,0,2,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,
 'ทาวน์โฮม 3 ชั้น ห้องมุม พื้นที่ใช้สอย 200 ตร.ม. ใกล้ BTS บางหว้า 600 เมตร เซ็นทรัล พระราม 2 สวนสมเด็จพระนางเจ้าสิริกิติ์ ฝ้าเพดานสูง 3 เมตร ครัวเปิด Island Kitchen รับสัตว์เลี้ยง',
 'a1',ARRAY['https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=800','https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800','https://images.unsplash.com/photo-1467533003447-e295ff1b0435?w=800','https://images.unsplash.com/photo-1613490493576-5f6ce62b17c9?w=800'],
 '2026-05-22'),

('p68','ทาวน์โฮมให้เช่า 3 ชั้น ใกล้ ม.เกษตร บางเขน','ทาวน์โฮม','กรุงเทพฯ','บางเขน-เกษตร กรุงเทพฯ',
 22000,'RENT',3,2,150,22,3,0,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,FALSE,
 'ทาวน์โฮม 3 ชั้น ให้เช่า ใกล้มหาวิทยาลัยเกษตรศาสตร์ บางเขน ตกแต่งบางส่วน 3 ห้องนอน 2 ห้องน้ำ รับสัตว์เลี้ยง ใกล้ตลาดนัดเซเว่น MRT เกษตรศาสตร์ เหมาะครอบครัวและนักศึกษา',
 'a4',ARRAY['https://images.unsplash.com/photo-1599427303058-f04cbcf4756f?w=800','https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=800','https://images.unsplash.com/photo-1574691250077-03a929faece5?w=800'],
 '2026-05-23'),

('p69','ทาวน์โฮม 2 ชั้น โครงการ Pruksa ชัยนาท','ทาวน์โฮม','ชัยนาท','เมือง ชัยนาท',
 1850000,'BUY',2,2,100,18,2,0,1,'none',FALSE,
 ARRAY['แอร์'],FALSE,FALSE,
 'ทาวน์โฮม 2 ชั้น โครงการพฤกษาวิลล์ ชัยนาท ราคาเริ่มต้น 1.85 ล้าน 2 ห้องนอน 2 ห้องน้ำ ผ่อนเพียง 5,500 บาท/เดือน ใกล้ตลาดโต้รุ่ง โรงพยาบาลชัยนาท เหมาะซื้อพักอาศัยและลงทุนปล่อยเช่า',
 'a4',ARRAY['https://images.unsplash.com/photo-1600566752447-b00f67e74a0e?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800'],
 '2026-05-24'),

('p70','ทาวน์โฮม 3 ชั้น หรู ใกล้สนามบินดอนเมือง','ทาวน์โฮม','กรุงเทพฯ','ดอนเมือง-รังสิต กรุงเทพฯ',
 4500000,'BUY',3,3,185,25,3,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ไมโครเวฟ'],FALSE,FALSE,
 'ทาวน์โฮม 3 ชั้น Premium ใกล้สนามบินดอนเมือง 10 นาที ตกแต่ง Full Built-in ฝ้าเพดานสูง ครัวยุโรป ที่จอดรถ 2 คัน ใกล้ Future Park รังสิต เหมาะพนักงานสายการบิน ครอบครัวย่านดอนเมือง',
 'a1',ARRAY['https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=800','https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=800','https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?w=800','https://images.unsplash.com/photo-1565372195458-cf3eced61daf?w=800','https://images.unsplash.com/photo-1599619585752-c3edb42a414c?w=800'],
 '2026-05-25'),

('p71','ทาวน์โฮม 3 ชั้น ย่านสุขุมวิท 103','ทาวน์โฮม','กรุงเทพฯ','อุดมสุข-สุขุมวิท 103 กรุงเทพฯ',
 6500000,'BUY',3,3,190,28,3,0,2,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,TRUE,
 'ทาวน์โฮม 3 ชั้น สไตล์ Modern Tropical ย่านอุดมสุข 3 ห้องนอน 3 ห้องน้ำ ดาดฟ้าส่วนตัว ห้อง Multi-Purpose ใกล้ BTS อุดมสุข Tesco Lotus อุดมสุข ทำเลดี ราคาคุ้มค่า',
 'a1',ARRAY['https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1613490493576-5f6ce62b17c9?w=800','https://images.unsplash.com/photo-1613545325278-f24b0cae1224?w=800','https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800','https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800'],
 '2026-05-26'),

('p72','ทาวน์โฮมให้เช่า ย่านนวนคร ปทุมธานี','ทาวน์โฮม','ปทุมธานี','นวนคร คลองหลวง ปทุมธานี',
 12000,'RENT',2,2,110,20,2,0,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'ทาวน์โฮม 2 ชั้น ให้เช่า ย่านนิคมอุตสาหกรรมนวนคร เหมาะพนักงานโรงงาน ตกแต่งบางส่วน 2 ห้องนอน รับสัตว์เลี้ยง ที่จอดรถ 1 คัน ใกล้โลตัส คลองหลวง สัญญา 12 เดือน',
 'a4',ARRAY['https://images.unsplash.com/photo-1599427303058-f04cbcf4756f?w=800','https://images.unsplash.com/photo-1484301548518-d0e0a5db0fc8?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800','https://images.unsplash.com/photo-1574691250077-03a929faece5?w=800'],
 '2026-05-27'),

('p73','ทาวน์โฮม 4 ชั้น Corner Unit ย่านพระโขนง','ทาวน์โฮม','กรุงเทพฯ','พระโขนง-ออนนุช กรุงเทพฯ',
 8200000,'BUY',4,4,280,35,4,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'ทาวน์โฮม 4 ชั้น Corner Unit พื้นที่ใช้สอย 280 ตร.ม. ย่านพระโขนง ตกแต่ง Full Built-in ทุกห้อง ดาดฟ้าส่วนตัว ใกล้ BTS พระโขนง 500 เมตร Habito Mall Gateway ราคาพิเศษ ทำเลอนาคตไกล',
 'a1',ARRAY['https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=800','https://images.unsplash.com/photo-1613490493576-5f6ce62b17c9?w=800','https://images.unsplash.com/photo-1565372195458-cf3eced61daf?w=800','https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800','https://images.unsplash.com/photo-1599619585752-c3edb42a414c?w=800'],
 '2026-05-28'),

-- ══════════════════════════════════════════════════════════════
-- วิลล่า (p74–p78)
-- ══════════════════════════════════════════════════════════════
('p74','Pool Villa หรู บ้านเอื้อม เกาะสมุย','วิลล่า','สุราษฎร์ธานี','แม่น้ำ เกาะสมุย สุราษฎร์ธานี',
 32000000,'BUY',5,5,600,250,2,0,4,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','โฮมเธียเตอร์','สมาร์ทโฮม'],FALSE,TRUE,
 'Pool Villa สุดหรู บ้านเอื้อม เกาะสมุย 5 ห้องนอน สระว่ายน้ำ Overflow ขนาด 15×5 เมตร สวนเขตร้อนส่วนตัว วิวทะเลอ่าวไทย Sala ริมสระ Chef Kitchen เหมาะลงทุนปล่อยเช่า Premium Yield 10-12% ต่อปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-05-29'),

('p75','วิลล่าให้เช่ารายเดือน วิวดอย เชียงดาว','วิลล่า','เชียงใหม่','เชียงดาว เชียงใหม่',
 65000,'RENT',3,3,280,300,1,0,4,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เตาผิง'],TRUE,TRUE,
 'วิลล่าตากอากาศ ให้เช่ารายเดือน วิวดอยเชียงดาวสวยงาม อากาศเย็นตลอดปี 3 ห้องนอน สระน้ำอุ่นส่วนตัว เตาผิง Jacuzzi สวนสนและไม้ดอก รับสัตว์เลี้ยง ห่างเมืองเชียงใหม่ 45 นาที เหมาะ Retreat และ Work from Nature',
 'a6',ARRAY['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800','https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800','https://images.unsplash.com/photo-1502672023488-70e25813eb80?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800'],
 '2026-05-30'),

('p76','วิลล่า Pool Villa ใหม่ ไม้ขาว ภูเก็ต','วิลล่า','ภูเก็ต','ไม้ขาว ถลาง ภูเก็ต',
 18500000,'BUY',3,3,350,120,1,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'วิลล่าชั้นเดียว สไตล์ Balinese Luxury ย่านไม้ขาว ห่างชายหาดไม้ขาว 400 เมตร สระว่ายน้ำ Private Pool ยาว 12 เมตร สวนเขตร้อน ห้องนอน 3 ห้อง ล้วน En-suite วิลล่าใหม่ปี 2025 พร้อมโอน',
 'a3',ARRAY['https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1598994942340-0a2e0e11c5bc?w=800','https://images.unsplash.com/photo-1610641818989-c2051b5e2cfd?w=800'],
 '2026-05-31'),

('p77','วิลล่า Hillside วิวทะเล เกาะช้าง ตราด','วิลล่า','ตราด','เกาะช้าง ตราด',
 14500000,'BUY',4,4,420,180,2,0,4,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'วิลล่า Hillside บนเนินเขา วิวทะเลอ่าวไทย 4 ห้องนอน สระว่ายน้ำ Infinity สวนส่วนตัว Sala ดาดฟ้า เกาะช้าง ตราด เหมาะ Holiday Villa และลงทุนปล่อยเช่านักท่องเที่ยว',
 'a3',ARRAY['https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-06-01'),

('p78','วิลล่าให้เช่า ริมน้ำ เชียงใหม่ Riverside','วิลล่า','เชียงใหม่','สารภี เชียงใหม่',
 80000,'RENT',4,4,360,200,1,0,4,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เตาผิง'],TRUE,FALSE,
 'วิลล่า 1 ชั้น ริมแม่น้ำปิง สไตล์ Lanna Contemporary ให้เช่ารายเดือน สระว่ายน้ำส่วนตัว ระเบียงวิวแม่น้ำ สวนไม้เมืองเหนือ รับสัตว์เลี้ยง ห่างเมืองเชียงใหม่ 20 นาที เหมาะ Expat ครอบครัวใหญ่',
 'a6',ARRAY['https://images.unsplash.com/photo-1610641818989-c2051b5e2cfd?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800'],
 '2026-06-02'),

-- ══════════════════════════════════════════════════════════════
-- ที่ดิน (p79–p84)
-- ══════════════════════════════════════════════════════════════
('p79','ที่ดินทำเลทอง ใกล้ BTS ม็อบ ตากสิน','ที่ดิน','กรุงเทพฯ','ตากสิน-วงเวียนใหญ่ กรุงเทพฯ',
 45000000,'BUY',0,0,0,360,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'ที่ดิน 360 ตร.วา ย่านตากสิน-วงเวียนใหญ่ ห่าง BTS กรุงธนบุรีเพียง 300 เมตร ทำเลทองใจกลางฝั่งธน เหมาะพัฒนา Condo หรือ Mixed Use ราคา Land Value สูงขึ้นต่อเนื่อง',
 'a3',ARRAY['https://images.unsplash.com/photo-1576673442511-7e39b6545c87?w=800','https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800','https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800','https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],
 '2026-06-03'),

('p80','ที่ดินเปล่า 5 ไร่ ใกล้ถนน 304 ฉะเชิงเทรา','ที่ดิน','ฉะเชิงเทรา','พนมสารคาม ฉะเชิงเทรา',
 6500000,'BUY',0,0,0,2000,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดินเปล่า 5 ไร่ ใกล้ถนนสาย 304 (ฉะเชิงเทรา-กบินทร์บุรี) โฉนดครุฑ พร้อมโอน ไฟฟ้า น้ำประปา เหมาะสร้างโรงงาน โกดัง ฟาร์ม หรือรีสอร์ท EEC Zone ราคาดีมาก',
 'a5',ARRAY['https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800','https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800','https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=800','https://images.unsplash.com/photo-1483086431886-3590a88317fe?w=800'],
 '2026-06-04'),

('p81','ที่ดินเชิงเขา วิวทะเล สูงสุด เกาะลันตา กระบี่','ที่ดิน','กระบี่','เกาะลันตา กระบี่',
 12000000,'BUY',0,0,0,600,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'ที่ดินเนินเขา 600 ตร.วา วิวทะเลอันดามันพาโนราม่า เกาะลันตา กระบี่ เหมาะสร้างวิลล่าวิวทะเล โรงแรม Boutique หรือรีสอร์ท ตลาดนักท่องเที่ยวกำลังบูม ราคาที่ดินเพิ่มขึ้น 15%/ปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800','https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800'],
 '2026-06-05'),

('p82','ที่ดินสร้างบ้าน 100 ตร.วา ย่านรามคำแหง','ที่ดิน','กรุงเทพฯ','รามคำแหง 24 กรุงเทพฯ',
 5800000,'BUY',0,0,0,100,0,0,0,'none',FALSE,ARRAY[]::TEXT[],TRUE,FALSE,
 'ที่ดินเปล่า 100 ตร.วา ย่านรามคำแหง ใกล้ MRT รามคำแหง ห้าง The Mall บางกะปิ ซอยสงบ น้ำไฟพร้อม โฉนดพร้อมโอน เหมาะสร้างบ้านหรือทาวน์โฮม',
 'a5',ARRAY['https://images.unsplash.com/photo-1558442074-3c19857bc1dc?w=800','https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800','https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800','https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'],
 '2026-06-06'),

('p83','ที่ดินติดแหล่งน้ำ ทำเกษตรอินทรีย์ สุพรรณบุรี','ที่ดิน','สุพรรณบุรี','เดิมบางนางบวช สุพรรณบุรี',
 1800000,'BUY',0,0,0,1600,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดินเกษตร 4 ไร่ ติดลำคลอง น้ำพอเพียงตลอดปี ดินร่วนซุยอุดมสมบูรณ์ เหมาะปลูกข้าว ผัก ผลไม้อินทรีย์ โฉนดครุฑ ห่างกรุงเทพฯ 120 กม. ราคาต่ำกว่าตลาดมาก',
 'a5',ARRAY['https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=800','https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800'],
 '2026-06-07'),

('p84','ที่ดินนิคมอุตสาหกรรม ระยอง WHA','ที่ดิน','ระยอง','ปลวกแดง ระยอง',
 28000000,'BUY',0,0,0,4800,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'ที่ดิน 12 ไร่ ในนิคมอุตสาหกรรม WHA ระยอง ระบบสาธารณูปโภคครบ ไฟฟ้า 3 เฟส น้ำอุตสาหกรรม ถนนภายในนิคม เหมาะสร้างโรงงาน คลังสินค้า พื้นที่ EEC ราคากำลังขึ้น นักลงทุนต่างชาติสนใจมาก',
 'a5',ARRAY['https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=800','https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800','https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=800','https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800'],
 '2026-06-08'),

-- ══════════════════════════════════════════════════════════════
-- อาคารพาณิชย์ (p85–p89)
-- ══════════════════════════════════════════════════════════════
('p85','อาคารพาณิชย์ 3 ชั้น ใกล้ห้าง Robinson ราชบุรี','อาคารพาณิชย์','ราชบุรี','เมือง ราชบุรี',
 4500000,'BUY',0,3,180,22,3,0,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'อาคารพาณิชย์ 3 ชั้น หน้ากว้าง 5 เมตร ใกล้ห้าง Robinson ราชบุรี ตลาดนัด ชั้นล่างเหมาะร้านค้า ชั้นบนอยู่อาศัย ปัจจุบันปล่อยเช่า 18,000 บาท/เดือน ผลตอบแทน 4.8% ต่อปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800','https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=800','https://images.unsplash.com/photo-1484101403633-562f891dc89a?w=800','https://images.unsplash.com/photo-1497366754035-91ee15a9d7e2?w=800'],
 '2026-06-09'),

('p86','อาคารพาณิชย์ให้เช่า 4 ชั้น ย่านเยาวราช','อาคารพาณิชย์','กรุงเทพฯ','เยาวราช-สำเพ็ง กรุงเทพฯ',
 85000,'RENT',0,4,250,28,4,0,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'อาคารพาณิชย์ 4 ชั้น ให้เช่า ย่านเยาวราช ทำเลทองค้าขาย ใกล้ MRT สนามไชย หน้ากว้าง 5.5 เมตร เหมาะร้านทอง ร้านอาหาร Showroom สินค้าหรู ค่าเช่ารวมค่าส่วนกลาง สัญญา 3 ปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800','https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800','https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2026-06-10'),

('p87','ตึกแถว 3 ชั้น ริมถนนใหญ่ อยุธยา','อาคารพาณิชย์','พระนครศรีอยุธยา','เมือง พระนครศรีอยุธยา',
 2800000,'BUY',0,2,120,18,3,0,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ตึกแถว 3 ชั้น ริมถนนสายเอเชีย อยุธยา หน้ากว้าง 4.5 เมตร โฉนดพร้อมโอน เหมาะเปิดร้านค้า ร้านอาหาร บริษัท SME ใกล้สถานีรถไฟอยุธยา แหล่งท่องเที่ยวประวัติศาสตร์',
 'a5',ARRAY['https://images.unsplash.com/photo-1615529328331-f8917597711f?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1497366216548-37526070297c?w=800','https://images.unsplash.com/photo-1615571022219-eb45cf7faa9d?w=800'],
 '2026-06-11'),

('p88','อาคารสำนักงาน 6 ชั้น ย่านพระราม 9','อาคารพาณิชย์','กรุงเทพฯ','พระราม 9-ห้วยขวาง กรุงเทพฯ',
 38000000,'BUY',0,12,800,120,6,0,10,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'อาคารสำนักงาน 6 ชั้น พื้นที่ใช้สอยรวม 800 ตร.ม. ย่านพระราม 9 ลิฟต์โดยสาร ระบบไฟฟ้า 3 เฟส ที่จอดรถ 10 คัน ใกล้ MRT พระราม 9 ปัจจุบันมีผู้เช่า รายได้ 180,000 บาท/เดือน ผลตอบแทน 5.7%',
 'a3',ARRAY['https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800','https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800','https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'],
 '2026-06-12'),

('p89','อาคารพาณิชย์ใหม่ให้เช่า โคราช ย่านโชคชัย','อาคารพาณิชย์','นครราชสีมา','โชคชัย นครราชสีมา',
 16000,'RENT',0,2,80,14,2,1,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'อาคารพาณิชย์ 2 ชั้น ให้เช่า ย่านโชคชัย นครราชสีมา ใหม่สร้าง 2025 หน้ากว้าง 4 เมตร เหมาะร้านค้า คลินิก สำนักงาน บัญชี นิติกรรม ค่าไฟฟ้า น้ำ แยกต่างหาก สัญญา 1 ปี',
 'a4',ARRAY['https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=800','https://images.unsplash.com/photo-1615571022219-eb45cf7faa9d?w=800','https://images.unsplash.com/photo-1497366216548-37526070297c?w=800','https://images.unsplash.com/photo-1484101403633-562f891dc89a?w=800','https://images.unsplash.com/photo-1497366754035-91ee15a9d7e2?w=800'],
 '2026-06-13'),

-- ══════════════════════════════════════════════════════════════
-- รีสอร์ท & โรงแรม (p90–p93)
-- ══════════════════════════════════════════════════════════════
('p90','รีสอร์ท 20 ห้อง ติดชายหาด เกาะพะงัน','รีสอร์ท','สุราษฎร์ธานี','บ่อผุด หาดริ้น เกาะพะงัน สุราษฎร์ธานี',
 58000000,'BUY',20,20,1800,600,2,0,30,'full',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'รีสอร์ทพรีเมียม 20 ห้อง ติดชายหาดริ้น เกาะพะงัน สระว่ายน้ำขนาดใหญ่ ร้านอาหาร Pool Bar Spa พร้อมดำเนินการ Occupancy เฉลี่ย 80% รายได้ 4-6 ล้าน/เดือน คืนทุน 8-10 ปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800','https://images.unsplash.com/photo-1613545325268-2f15f20d2670?w=800'],
 '2026-06-14'),

('p91','โรงแรม Boutique 30 ห้อง ย่านนิมมาน เชียงใหม่','โรงแรม','เชียงใหม่','นิมมานเหมินท์ เชียงใหม่',
 45000000,'BUY',30,30,1500,200,4,0,20,'full',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'โรงแรม Boutique 4 ชั้น 30 ห้อง ย่านนิมมาน สไตล์ Lanna Chic สระว่ายน้ำดาดฟ้า ร้านอาหาร Rooftop Bar พร้อมดำเนินการ ใกล้ One Nimman และ MAYA Mall Occupancy 85% รายได้ 3+ ล้าน/เดือน',
 'a6',ARRAY['https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1613545325268-2f15f20d2670?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800','https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800'],
 '2026-06-15'),

('p92','รีสอร์ทให้เช่ากิจการ 15 ห้อง เกาะสมุย','รีสอร์ท','สุราษฎร์ธานี','แม่น้ำ เกาะสมุย สุราษฎร์ธานี',
 350000,'RENT',15,15,1000,400,2,0,20,'full',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'รีสอร์ท 15 ห้อง เกาะสมุย ให้เช่ากิจการรายปี สระว่ายน้ำ ร้านอาหาร ส่งมอบพร้อมอุปกรณ์ครบ Occupancy เฉลี่ย 70% เหมาะนักลงทุนที่ต้องการบริหารกิจการโรงแรมขนาดกลาง',
 'a3',ARRAY['https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1613545325268-2f15f20d2670?w=800','https://images.unsplash.com/photo-1448630360428-65456885c650?w=800'],
 '2026-06-16'),

('p93','โรงแรม Capsule 50 ห้อง ใกล้สถานีหัวลำโพง','โรงแรม','กรุงเทพฯ','หัวลำโพง-เยาวราช กรุงเทพฯ',
 32000000,'BUY',50,10,800,80,5,0,5,'full',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'โรงแรม Capsule สไตล์ Modern ย่านหัวลำโพง 50 Capsule Rooms ชั้น 5 Rooftop Café ร้านอาหาร พร้อมดำเนินการ ใกล้ MRT หัวลำโพง เยาวราช ทราฟฟิกนักท่องเที่ยวสูง Occupancy 90%',
 'a3',ARRAY['https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800','https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=800','https://images.unsplash.com/photo-1574691250077-03a929faece5?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800'],
 '2026-06-17'),

-- ══════════════════════════════════════════════════════════════
-- บ้านเดี่ยว / คอนโด / ทาวน์โฮม เพิ่มเติม (p94–p95)
-- ══════════════════════════════════════════════════════════════
('p94','คอนโด Studio ให้เช่า ย่านอ่อนนุช ราคาพิเศษ','คอนโด','กรุงเทพฯ','อ่อนนุช-บางจาก กรุงเทพฯ',
 11000,'RENT',0,1,25,0,0,6,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี'],FALSE,FALSE,
 'คอนโดสตูดิโอ ให้เช่าราคาประหยัด เฟอร์นิเจอร์ครบ ชั้น 6 อินเตอร์เน็ต Fiber รวมในค่าเช่า ใกล้ BTS อ่อนนุช Gateway Mall เหมาะนักศึกษา มนุษย์เงินเดือน งบน้อย พื้นที่กะทัดรัดแต่ตกแต่งสวย',
 'a2',ARRAY['https://images.unsplash.com/photo-1614168092736-01bd2b8c8821?w=800','https://images.unsplash.com/photo-1600210492493-0946911123ea?w=800','https://images.unsplash.com/photo-1562182384-08115de5ee97?w=800','https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800'],
 '2026-06-18'),

('p95','บ้านเดี่ยว 2 ชั้น โครงการ Anasiri นครนายก','บ้านเดี่ยว','นครนายก','เมือง นครนายก',
 4200000,'BUY',3,3,175,80,2,0,2,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,TRUE,
 'บ้านเดี่ยว 2 ชั้น โครงการ Anasiri นครนายก บนที่ดิน 80 ตร.วา 3 ห้องนอน 3 ห้องน้ำ ใกล้สวนสาธารณะ วังน้ำเขียว เขาใหญ่ อากาศดี เหมาะ Weekend House ครอบครัวที่ต้องการพักผ่อน รับสัตว์เลี้ยง',
 'a1',ARRAY['https://images.unsplash.com/photo-1611117775350-ac3950990985?w=800','https://images.unsplash.com/photo-1605146769289-440113cc3d00?w=800','https://images.unsplash.com/photo-1560184897-67f4a3f9a7fa?w=800','https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800','https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=800'],
 '2026-06-19')

ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- อัปเดต prop_ids ของ agents (เพิ่ม p46–p95)
-- ============================================================
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p46','p50','p51','p53','p71','p73','p95']) WHERE id = 'a1';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p55','p56','p57','p59','p60','p61','p63','p64','p65','p94']) WHERE id = 'a2';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p49','p66','p74','p76','p77','p79','p81','p85','p86','p88','p90','p91','p92','p93']) WHERE id = 'a3';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p48','p52','p53','p61','p65','p68','p69','p72','p89']) WHERE id = 'a4';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p46','p58','p62','p80','p82','p83','p84','p87']) WHERE id = 'a5';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p51','p54','p75','p78','p91']) WHERE id = 'a6';

-- ============================================================
-- ✅ DONE — Patch v9.1
-- สรุปข้อมูลที่เพิ่มเข้ามาในแพทช์นี้:
--   properties ใหม่  : 50 รายการ (p46–p95)
--   รวม properties   : 95 รายการ
--   ประเภทที่เพิ่ม  :
--     บ้านเดี่ยว     +9  รายการ (p46–p54, p95)  ← รวม 10 ใน patch
--     คอนโด         +12 รายการ (p55–p66, p94)   ← รวม 13 ใน patch
--     ทาวน์โฮม       +7  รายการ (p67–p73)
--     วิลล่า         +5  รายการ (p74–p78)
--     ที่ดิน          +6  รายการ (p79–p84)
--     อาคารพาณิชย์   +5  รายการ (p85–p89)
--     รีสอร์ท        +3  รายการ (p90, p92)
--     โรงแรม         +2  รายการ (p91, p93)
--   ครอบคลุมจังหวัด  :
--     กรุงเทพฯ ชลบุรี เชียงใหม่ ภูเก็ต สุราษฎร์ธานี กระบี่ ตราด
--     นครราชสีมา ราชบุรี ฉะเชิงเทรา ระยอง อุดรธานี สุพรรณบุรี
--     พระนครศรีอยุธยา ประจวบคีรีขันธ์ นครนายก นนทบุรี ปทุมธานี
-- ============================================================

-- ============================================================
-- MATCHDOOR — SQL Patch v11.0
-- เพิ่มข้อมูลจำลอง:
--   • portfolio  +4  รายการ (pt09–pt12)
--   • services   +4  รายการ (pest, move, photo, legal)
--   • blogs      +4  รายการ
--   • properties +40 รายการ (p96–p135)
-- Updated : 2026 (พฤษภาคม)
-- ============================================================

-- ============================================================
-- A. SEED: portfolio เพิ่มเติม (pt09–pt12)
-- ============================================================
INSERT INTO portfolio (id, title, type, price, status, location, date, review, photo, photos) VALUES
('pt09','คอนโด 1 ห้องนอน ลาดพร้าว ปิดดีลไว 30 วัน','คอนโด',2850000,'SOLD','ลาดพร้าว กรุงเทพฯ','มิ.ย. 2569',
 'ขายได้ภายใน 30 วัน ราคาตามที่ตั้งไว้ ทีม Matchdoor ช่วยถ่ายรูป ทำ Virtual Tour ทำให้มีผู้สนใจเข้าชมหลายราย ประทับใจบริการมาก จะกลับมาใช้บริการอีกแน่นอน',
 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400',
 ARRAY['https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800','https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=800']),

('pt10','บ้านเดี่ยว 2 ชั้น เชียงใหม่ ปล่อยเช่าสำเร็จ','บ้านเดี่ยว',30000,'RENTED','แม่ริม เชียงใหม่','มิ.ย. 2569',
 'ได้ผู้เช่าชาวเดนมาร์ก สัญญา 12 เดือน ผ่านการตรวจสอบประวัติครบ พี่อาภาพรดูแลตลอด ภาษาอังกฤษดีมาก สื่อสารกับชาวต่างชาติได้ราบรื่น ขอบคุณมากครับ',
 'https://images.unsplash.com/photo-1611117775350-ac3950990985?w=400',
 ARRAY['https://images.unsplash.com/photo-1611117775350-ac3950990985?w=800','https://images.unsplash.com/photo-1605146769289-440113cc3d00?w=800']),

('pt11','ทาวน์โฮม 3 ชั้น พัทยา ขายก่อนประกาศ','ทาวน์โฮม',5200000,'SOLD','บางละมุง ชลบุรี','ก.ค. 2569',
 'ขายได้ก่อนออกประกาศเลย พี่ณัฐพลมีฐานลูกค้านักลงทุนดีมาก ดีลจบใน 3 วัน ราคาสูงกว่าที่คิดไว้ 5% ไม่ต้องเสียเวลาถ่ายรูป ออกประกาศ แนะนำสุดๆ',
 'https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=400',
 ARRAY['https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800']),

('pt12','ที่ดิน 3 ไร่ ระยอง ขายนักลงทุนญี่ปุ่น','ที่ดิน',28500000,'SOLD','มาบตาพุด ระยอง','ก.ค. 2569',
 'ขายให้นักลงทุนญี่ปุ่นได้ใน 45 วัน พี่ภาณุพงศ์จัดทำเอกสารภาษาญี่ปุ่นและอังกฤษให้ครบ แปลสัญญาให้ ประสานงานกับกรมที่ดิน ราคาดีกว่าตลาดมาก เกินความคาดหวัง',
 'https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=400',
 ARRAY['https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=800','https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800'])

ON CONFLICT (id) DO UPDATE SET
  title=EXCLUDED.title, type=EXCLUDED.type, price=EXCLUDED.price, status=EXCLUDED.status,
  location=EXCLUDED.location, date=EXCLUDED.date, review=EXCLUDED.review,
  photo=EXCLUDED.photo, photos=EXCLUDED.photos;

-- ============================================================
-- B. SEED: services เพิ่มเติม (pest, move, photo, legal)
-- ============================================================
INSERT INTO services (id, name, icon, short_desc, full_desc, price, duration, sort_order) VALUES
('pest','กำจัดปลวกและแมลง','fa-bug','กำจัดปลวก แมลงสาบ หนู ครบจบในที่เดียว',
 'บริการกำจัดปลวก มด แมลงสาบ หนู และแมลงรบกวนทุกชนิด ใช้สารเคมีที่ได้รับอนุญาตจากกรมวิชาการเกษตร ปลอดภัยต่อมนุษย์และสัตว์เลี้ยง รับประกันงาน 6 เดือน พร้อมรายงานการตรวจสอบรายปี',
 '1,200 บาท+','2-4 ชั่วโมง',7),

('move','ขนย้ายบ้านมืออาชีพ','fa-truck','บริการขนย้ายครบวงจร ทั่วประเทศ',
 'บริการขนย้ายบ้านและสำนักงาน ทั้งในกรุงเทพฯ ปริมณฑล และต่างจังหวัด มีรถบรรทุกหลายขนาด บรรจุหีบห่อให้ฟรี ทีมงานผ่านการฝึกอบรม มีประกันภัยสินค้าระหว่างขนย้าย บริการทุกวันรวมวันหยุด',
 '2,500 บาท+','ตามระยะทาง',8),

('photo','ถ่ายภาพอสังหาฯ มืออาชีพ','fa-camera','ถ่ายรูปบ้าน คอนโด Virtual Tour 3D',
 'บริการถ่ายภาพอสังหาริมทรัพย์ระดับมืออาชีพ กล้อง Full Frame ตกแต่งภาพคุณภาพสูง รวมถึง Drone Shot วิวมุมสูง Virtual Tour 360° ด้วย Matterport และ Floor Plan 2D/3D ช่วยให้ทรัพย์ขายได้เร็วขึ้น 3 เท่า',
 '3,500 บาท+','2-3 ชั่วโมง',9),

('legal','บริการนิติกรรมอสังหาฯ','fa-file-contract','ตรวจโฉนด ร่างสัญญา จดทะเบียนโอน',
 'บริการครบวงจรด้านนิติกรรมอสังหาริมทรัพย์ ตรวจสอบโฉนดและภาระผูกพัน ร่างสัญญาซื้อขาย สัญญาเช่า สัญญาจะซื้อจะขาย ประสานงานกรมที่ดิน คำนวณภาษีและค่าธรรมเนียม ดูแลจนถึงวันโอน',
 '5,000 บาท+','1-7 วัน',10)

ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, icon=EXCLUDED.icon, short_desc=EXCLUDED.short_desc,
  full_desc=EXCLUDED.full_desc, price=EXCLUDED.price, duration=EXCLUDED.duration,
  sort_order=EXCLUDED.sort_order;

-- ============================================================
-- C. SEED: blogs เพิ่มเติม (4 บทความ)
-- ============================================================
INSERT INTO blogs (title, cat, date, icon, color, content, photos, sort_order, is_published) VALUES

('5 เหตุผลที่ควรใช้นายหน้ามืออาชีพแทนขายเอง','คำแนะนำ','15 มิ.ย. 2569','💼',
 'linear-gradient(135deg,#0f2027,#203a43,#2c5364)',
 '<p>หลายคนคิดว่าการขายบ้านเองช่วยประหยัดค่านายหน้า แต่ข้อมูลจริงๆ พบว่าบ้านที่ขายผ่านนายหน้ามืออาชีพได้ราคาสูงกว่าถึง 10-15%</p><h3>5 เหตุผลสำคัญ</h3><ol><li><strong>ฐานข้อมูลผู้ซื้อ</strong>: นายหน้ามีลูกค้าในมือพร้อม ลดเวลาขายจาก 6 เดือนเหลือ 6 สัปดาห์</li><li><strong>การตีราคาที่แม่นยำ</strong>: ตีราคาจากข้อมูลตลาดจริง ไม่สูงหรือต่ำเกินไป</li><li><strong>การตลาดมืออาชีพ</strong>: ถ่ายรูป Drone ลง Portal หลัก Reach หลักแสน</li><li><strong>เจรจาต่อรองแทน</strong>: ได้ราคาดีกว่า เพราะไม่มีอารมณ์เข้ามาเกี่ยว</li><li><strong>ดูแลเอกสาร</strong>: ประสานงานธนาคาร กรมที่ดิน ไม่ผิดพลาด</li></ol><p>สรุป: ค่านายหน้า 3% ที่จ่ายไป มักได้กลับคืนมาในรูปราคาที่สูงขึ้นและความเร็วในการขาย</p>',
 ARRAY['https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800','https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800'],6,TRUE),

('Digital Nomad เลือกอยู่ที่ไหนในไทย 2569','ไลฟ์สไตล์','1 มิ.ย. 2569','💻',
 'linear-gradient(135deg,#1a1a2e,#16213e,#0f3460)',
 '<p>Digital Nomad ชาวต่างชาติเลือกประเทศไทยมากขึ้นทุกปี เนื่องจาก Visa LTR (Long-Term Resident) และ Digital Nomad Visa ที่รัฐบาลออกมา แล้วควรอยู่ที่ไหนดี?</p><h3>เปรียบเทียบ 3 เมือง</h3><table border="0" cellpadding="8" style="width:100%;border-collapse:collapse;font-size:13px"><tr style="background:#f0eeff"><th>เมือง</th><th>ค่าใช้จ่าย/เดือน</th><th>Speed Internet</th><th>Community</th></tr><tr><td>เชียงใหม่</td><td>25,000-45,000 บ.</td><td>⭐⭐⭐⭐⭐</td><td>ใหญ่มาก</td></tr><tr><td>กรุงเทพฯ</td><td>40,000-80,000 บ.</td><td>⭐⭐⭐⭐⭐</td><td>ใหญ่ที่สุด</td></tr><tr><td>ภูเก็ต</td><td>45,000-90,000 บ.</td><td>⭐⭐⭐⭐</td><td>กำลังเติบโต</td></tr></table><h3>คอนโดแนะนำสำหรับ Nomad</h3><ul><li>เชียงใหม่ ย่านนิมมาน: 12,000-20,000 บ./เดือน</li><li>กรุงเทพฯ ใกล้ BTS: 15,000-30,000 บ./เดือน</li><li>ภูเก็ต ป่าตอง-กะรน: 20,000-50,000 บ./เดือน</li></ul>',
 ARRAY['https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=800','https://images.unsplash.com/photo-1531297484001-80022131f5a1?w=800'],7,TRUE),

('คู่มือโอนกรรมสิทธิ์อสังหาฯ ฉบับสมบูรณ์','สาระน่ารู้','20 พ.ค. 2569','📝',
 'linear-gradient(135deg,#11998e,#38ef7d)',
 '<p>วันโอนกรรมสิทธิ์เป็นวันสำคัญที่สุดในกระบวนการซื้อขายอสังหาฯ ต้องเตรียมตัวอะไรบ้าง?</p><h3>เอกสารที่ต้องเตรียม (ผู้ซื้อ)</h3><ul><li>บัตรประชาชน + สำเนา 3 ชุด</li><li>ทะเบียนบ้าน + สำเนา 3 ชุด</li><li>หนังสือสัญญากู้ (กรณีกู้ธนาคาร)</li><li>หนังสือมอบอำนาจ (กรณีมีตัวแทน)</li></ul><h3>ค่าธรรมเนียมที่ต้องจ่าย</h3><ul><li><strong>ค่าโอน</strong>: 2% ของราคาประเมิน (แบ่งจ่าย 50:50 หรือตามตกลง)</li><li><strong>ภาษีธุรกิจเฉพาะ</strong>: 3.3% (กรณีถือครองน้อยกว่า 5 ปี)</li><li><strong>อากรแสตมป์</strong>: 0.5% (กรณีไม่เสีย SBT)</li><li><strong>ภาษีหัก ณ ที่จ่าย</strong>: คำนวณตามสูตรกรมสรรพากร</li></ul><p>แนะนำคำนวณล่วงหน้าผ่านแอป กรมที่ดิน หรือปรึกษาทีมนิติกรรม Matchdoor ฟรี</p>',
 ARRAY['https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800','https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800'],8,TRUE),

('ลงทุนอสังหาฯ ให้ปล่อยเช่า Yield สูง ทำอย่างไร','การลงทุน','5 พ.ค. 2569','💰',
 'linear-gradient(135deg,#f7971e,#ffd200)',
 '<p>การลงทุนอสังหาฯ เพื่อปล่อยเช่าเป็นทางเลือกที่ดีในยุคดอกเบี้ยสูง แต่ต้องเลือกให้ถูก</p><h3>สูตรเลือกทรัพย์ให้เช่า Yield ดี</h3><ul><li><strong>ทำเล</strong>: ใกล้ BTS/MRT มหาวิทยาลัย นิคมอุตสาหกรรม หรือแหล่งท่องเที่ยว</li><li><strong>ขนาด</strong>: Studio ถึง 1BR มีสภาพคล่องสูงสุด หาผู้เช่าง่ายกว่า</li><li><strong>ราคา</strong>: ซื้อ Resale ราคาต่ำกว่า Developer ให้ Yield สูงกว่า</li><li><strong>สภาพ</strong>: ตกแต่งครบ ราคาเช่าสูงกว่า 20-30% เพิ่มค่าใช้จ่ายแต่คุ้มค่า</li></ul><h3>ตัวอย่าง Yield จริงในตลาด 2569</h3><ul><li>คอนโด ใกล้ BTS กรุงเทพฯ: Gross Yield 4-6%</li><li>คอนโด พัทยา/ภูเก็ต: Gross Yield 6-10%</li><li>บ้านเดี่ยว ให้เช่า Expat: Gross Yield 5-7%</li><li>อาคารพาณิชย์ ย่านธุรกิจ: Gross Yield 4-6%</li></ul><p>ปรึกษาทีม Matchdoor ฟรี เพื่อคัดเลือกทรัพย์ที่ตรงเป้าการลงทุนของคุณ</p>',
 ARRAY['https://images.unsplash.com/photo-1559526324-593bc073d938?w=800','https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800'],9,TRUE)

ON CONFLICT DO NOTHING;

-- ============================================================
-- D. SEED: properties เพิ่มเติม 40 รายการ (p96–p135)
-- ============================================================
INSERT INTO properties
  (id, title, type, province, location, price, tx, bed, bath, area, land_area,
   floors, floor_no, parking, furniture, pets_allowed, appliances,
   is_new, is_rec, description, agent_id, photos, created_at)
VALUES

-- ══════════════════════════════════════════════════════════════
-- บ้านเดี่ยว (p96–p103)
-- ══════════════════════════════════════════════════════════════
('p96','บ้านเดี่ยว 2 ชั้น Passio สาทร กรุงเทพฯ','บ้านเดี่ยว','กรุงเทพฯ','สาทร-นราธิวาส กรุงเทพฯ',
 22000000,'BUY',4,4,360,75,2,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม'],FALSE,TRUE,
 'บ้านเดี่ยว 2 ชั้น สไตล์ Luxury Contemporary ย่านสาทร 4 ห้องนอน 4 ห้องน้ำ สระว่ายน้ำส่วนตัว ห้องฟิตเนส สวนส่วนตัว ใกล้ BTS ช่องนนทรีเพียง 800 เมตร ครัวยุโรป Island Kitchen ระบบกล้องวงจรปิด AI',
 'a1',ARRAY['https://images.unsplash.com/photo-1604328698692-f76ea9498e76?w=800','https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800','https://images.unsplash.com/photo-1565402170291-8491f14678db?w=800','https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800'],
 '2026-07-01'),

('p97','บ้านเดี่ยวให้เช่า 2 ชั้น วิวสวน พระราม 2','บ้านเดี่ยว','กรุงเทพฯ','พระราม 2-สมุทรสาคร กรุงเทพฯ',
 35000,'RENT',3,3,200,65,2,0,2,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,FALSE,
 'บ้านเดี่ยว 2 ชั้น ให้เช่า ย่านพระราม 2 เฟอร์นิเจอร์ครบ สวนหน้าบ้านขนาดใหญ่ รับสัตว์เลี้ยง ที่จอดรถ 2 คัน ใกล้ห้างเซ็นทรัล พระราม 2 โรงเรียนนานาชาติ St.Andrews เหมาะครอบครัว Expat',
 'a1',ARRAY['https://images.unsplash.com/photo-1439792675105-701e6a4ab6f0?w=800','https://images.unsplash.com/photo-1623298317883-198303c50eed?w=800','https://images.unsplash.com/photo-1516455207474-a4887912729c?w=800','https://images.unsplash.com/photo-1484154218962-a197022b6967?w=800','https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800'],
 '2026-07-02'),

('p98','บ้านเดี่ยว Smart Home ใหม่ วังน้อย อยุธยา','บ้านเดี่ยว','พระนครศรีอยุธยา','วังน้อย พระนครศรีอยุธยา',
 3900000,'BUY',3,2,160,60,2,0,2,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','สมาร์ทโฮม'],TRUE,FALSE,
 'บ้านเดี่ยว 2 ชั้น Smart Home ระบบ IoT ควบคุมผ่านมือถือ โครงการใหม่ปี 2025 ใกล้โรงงาน Navanakorn Industrial Estate เหมาะพนักงานนิคมอุตสาหกรรม ดอกเบี้ย 0% 2 ปีแรก',
 'a1',ARRAY['https://images.unsplash.com/photo-1543071220-6ee5bf71a54e?w=800','https://images.unsplash.com/photo-1572120360610-d971b9d7767c?w=800','https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?w=800','https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800'],
 '2026-07-03'),

('p99','บ้านเดี่ยว 3 ชั้น Modern ใกล้ BTS พระโขนง','บ้านเดี่ยว','กรุงเทพฯ','พระโขนง-อ่อนนุช กรุงเทพฯ',
 14500000,'BUY',4,4,320,68,3,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม'],FALSE,TRUE,
 'บ้านเดี่ยว 3 ชั้น สไตล์ Modern Box ย่านพระโขนง บันไดหินอ่อน ห้อง Master ชั้น 3 Walk-in Closet ดาดฟ้าส่วนตัว ใกล้ BTS พระโขนง 500 เมตร Habito Mall Gateway ทำเลอนาคตดีมาก',
 'a1',ARRAY['https://images.unsplash.com/photo-1604328698692-f76ea9498e76?w=800','https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800','https://images.unsplash.com/photo-1613545325278-f24b0cae1224?w=800','https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800','https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800'],
 '2026-07-04'),

('p100','บ้านเดี่ยวตากอากาศ วิวภูเขา เพชรบูรณ์','บ้านเดี่ยว','เพชรบูรณ์','เขาค้อ เพชรบูรณ์',
 6800000,'BUY',3,2,220,200,1,0,3,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เตาผิง'],TRUE,TRUE,
 'บ้านเดี่ยวตากอากาศ เขาค้อ สไตล์ Rustic Chalet วิวทะเลหมอก ป่าสน อากาศเย็นสบายตลอดปี เตาผิง ระเบียงวิวภูเขา รับสัตว์เลี้ยง บนที่ดิน 200 ตร.วา เหมาะ Weekend House และ Airbnb',
 'a6',ARRAY['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800','https://images.unsplash.com/photo-1484301548518-d0e0a5db0fc8?w=800','https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-07-05'),

('p101','บ้านเดี่ยว 2 ชั้น ขอนแก่น ใกล้ ม.ขอนแก่น','บ้านเดี่ยว','ขอนแก่น','เมือง ขอนแก่น',
 3500000,'BUY',3,2,160,65,2,0,2,'partial',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],FALSE,FALSE,
 'บ้านเดี่ยว 2 ชั้น ใกล้มหาวิทยาลัยขอนแก่น โรงพยาบาลศรีนครินทร์ ห้างเซ็นทรัล 3 ห้องนอน 2 ห้องน้ำ สวนหน้าบ้าน ที่จอดรถ 2 คัน เหมาะครอบครัวและลงทุนปล่อยเช่านักศึกษาแพทย์',
 'a4',ARRAY['https://images.unsplash.com/photo-1602343168117-bb8ffe3e2e9f?w=800','https://images.unsplash.com/photo-1628624747186-a941c476b7ef?w=800','https://images.unsplash.com/photo-1582719508491-a3a1e6b7e0e0?w=800','https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800','https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800'],
 '2026-07-06'),

('p102','บ้านเดี่ยวให้เช่า ใกล้สนามบินอู่ตะเภา ระยอง','บ้านเดี่ยว','ระยอง','บ้านฉาง ระยอง',
 22000,'RENT',3,2,160,60,2,0,2,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],TRUE,FALSE,
 'บ้านเดี่ยว 2 ชั้น ให้เช่า ใกล้สนามบินอู่ตะเภา 10 นาที นิคมอุตสาหกรรม EEC เฟอร์นิเจอร์ครบ รับสัตว์เลี้ยง เหมาะพนักงานนิคม ครอบครัวชาวต่างชาติที่มาทำงานใน EEC',
 'a5',ARRAY['https://images.unsplash.com/photo-1513584684374-8bab748fbf90?w=800','https://images.unsplash.com/photo-1484154218962-a197022b6967?w=800','https://images.unsplash.com/photo-1516455207474-a4887912729c?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800'],
 '2026-07-07'),

('p103','บ้านเดี่ยว 2 ชั้น ชุมพร ติดชายหาด','บ้านเดี่ยว','ชุมพร','หาดทุ่งวัวแล่น ชุมพร',
 9800000,'BUY',3,3,240,120,2,0,3,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'บ้านเดี่ยวติดชายหาดทุ่งวัวแล่น ชุมพร ห่างทะเล 80 เมตร 3 ห้องนอน สวนส่วนตัว ระเบียงวิวทะเล รับสัตว์เลี้ยง ชุมพรยังเป็นเมืองที่ราคาดีมาก คาดราคาที่ดินขึ้น 15% ใน 3 ปีข้างหน้า',
 'a3',ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800','https://images.unsplash.com/photo-1598994942340-0a2e0e11c5bc?w=800','https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800'],
 '2026-07-08'),

-- ══════════════════════════════════════════════════════════════
-- คอนโด (p104–p115)
-- ══════════════════════════════════════════════════════════════
('p104','คอนโด 1 ห้องนอน ใกล้ BTS บางจาก สุขุมวิท 71','คอนโด','กรุงเทพฯ','บางจาก-สุขุมวิท 71 กรุงเทพฯ',
 3800000,'BUY',1,1,38,0,0,11,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,FALSE,
 'คอนโด 1 ห้องนอน ชั้น 11 ตกแต่ง Built-in สไตล์ Japandi ใกล้ BTS บางจาก 400 เมตร ฟิตเนส สระว่ายน้ำ Rooftop Garden ราคาต่ำกว่าตลาดย่านนี้ เหมาะซื้อลงทุนปล่อยเช่า Yield 5-6%',
 'a2',ARRAY['https://images.unsplash.com/photo-1619994403073-2cec844b8e63?w=800','https://images.unsplash.com/photo-1614168092736-01bd2b8c8821?w=800','https://images.unsplash.com/photo-1600210491892-03d54c0aaf87?w=800','https://images.unsplash.com/photo-1628744448840-55bdb2497bd4?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],
 '2026-07-09'),

('p105','คอนโดให้เช่า วิวสวนจตุจักร ใกล้ BTS','คอนโด','กรุงเทพฯ','จตุจักร-ลาดพร้าว กรุงเทพฯ',
 20000,'RENT',1,1,40,0,0,9,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโด 1 ห้องนอน ชั้น 9 วิวสวนจตุจักร เฟอร์นิเจอร์ครบ ใกล้ BTS หมอชิต MRT จตุจักร ตลาดนัดจตุจักร อินเตอร์เน็ต Fiber รวม เหมาะมนุษย์เงินเดือน ชอบ Active Lifestyle',
 'a2',ARRAY['https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=800','https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1560185008-b033106af5c3?w=800','https://images.unsplash.com/photo-1556020685-ae41abfc9365?w=800'],
 '2026-07-10'),

('p106','คอนโด 2 ห้องนอน High-Rise ใกล้ MRT ลาดพร้าว','คอนโด','กรุงเทพฯ','ลาดพร้าว กรุงเทพฯ',
 6200000,'BUY',2,2,65,0,0,20,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ไมโครเวฟ'],TRUE,TRUE,
 'คอนโด 2 ห้องนอน ชั้น 20 วิวเมือง ใกล้ MRT ลาดพร้าว ห้าง Union Mall เซ็นทรัล ลาดพร้าว ตกแต่ง Built-in ครบ สระว่ายน้ำ ฟิตเนส EV Charger ในลานจอดรถ โครงการใหม่พร้อมอยู่',
 'a2',ARRAY['https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800','https://images.unsplash.com/photo-1592595896616-c37162298647?w=800','https://images.unsplash.com/photo-1600047509358-9dc75507daeb?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800'],
 '2026-07-11'),

('p107','คอนโดให้เช่า ราคาถูก ใกล้ ม.บูรพา ชลบุรี','คอนโด','ชลบุรี','เมือง ชลบุรี',
 7000,'RENT',1,1,28,0,0,3,0,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี'],FALSE,FALSE,
 'คอนโดสตูดิโอ ราคาถูก ให้เช่า เฟอร์นิเจอร์ครบ ชั้น 3 ใกล้มหาวิทยาลัยบูรพา ชลบุรี เหมาะนักศึกษา ค่าส่วนกลางรวมในค่าเช่า อินเตอร์เน็ต Fiber ห้องสะอาด เรียบร้อย',
 'a5',ARRAY['https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800','https://images.unsplash.com/photo-1441986300927-91d9e4a5e1fc?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1614168092736-01bd2b8c8821?w=800','https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800'],
 '2026-07-12'),

('p108','คอนโด 2 ห้องนอน ใหม่ สะพานใหม่ ดอนเมือง','คอนโด','กรุงเทพฯ','สะพานใหม่-ดอนเมือง กรุงเทพฯ',
 2800000,'BUY',2,1,48,0,0,7,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'คอนโด 2 ห้องนอน ราคาประหยัด โครงการใหม่ ชั้น 7 ตกแต่งบางส่วน ใกล้สนามบินดอนเมือง ตลาดยิ่งเจริญ Future Park รังสิต ผ่อนเพียง 9,500 บาท/เดือน เหมาะมือใหม่ซื้อบ้านหลังแรก',
 'a4',ARRAY['https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800','https://images.unsplash.com/photo-1600210492493-0946911123ea?w=800','https://images.unsplash.com/photo-1562182384-08115de5ee97?w=800','https://images.unsplash.com/photo-1617325247661-675ab4b64ae2?w=800','https://images.unsplash.com/photo-1583608205776-bfd35f0d9f83?w=800'],
 '2026-07-13'),

('p109','คอนโดให้เช่า Sea View ชะอำ เพชรบุรี','คอนโด','เพชรบุรี','ชะอำ เพชรบุรี',
 18000,'RENT',1,1,45,0,0,8,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโด 1 ห้องนอน วิวทะเลชะอำ ชั้น 8 เฟอร์นิเจอร์ครบ ให้เช่ารายเดือน/รายปี สระว่ายน้ำ Infinity ริมทะเล ใกล้ถนนเพชรเกษม เหมาะ Long Stay ผู้เกษียณ และครอบครัวที่ต้องการพักผ่อน',
 'a3',ARRAY['https://images.unsplash.com/photo-1540519338287-7c3f9a68ac3d?w=800','https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800','https://images.unsplash.com/photo-1565182999561-18d7dc61c393?w=800','https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800'],
 '2026-07-14'),

('p110','คอนโด 1 ห้องนอน ใหม่ BTS สำโรง สมุทรปราการ','คอนโด','สมุทรปราการ','สำโรง สมุทรปราการ',
 2500000,'BUY',1,1,36,0,0,10,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'คอนโดใหม่ 1 ห้องนอน ชั้น 10 ราคาดีที่สุดในย่านสำโรง ใกล้ BTS สำโรง 600 เมตร ห้างพาราไดซ์ พาร์ค สมิติเวช ศรีนครินทร์ ผ่อนเพียง 8,000 บาท/เดือน เหมาะมือใหม่',
 'a4',ARRAY['https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800','https://images.unsplash.com/photo-1628744448840-55bdb2497bd4?w=800','https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800','https://images.unsplash.com/photo-1523217582562-09d0def993a6?w=800','https://images.unsplash.com/photo-1600210491892-03d54c0aaf87?w=800'],
 '2026-07-15'),

('p111','คอนโด Sky Residences วิวแม่น้ำ เจ้าพระยา นนทบุรี','คอนโด','นนทบุรี','ท่าน้ำ นนทบุรี',
 8500000,'BUY',2,2,82,0,0,24,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'คอนโด High-Rise ชั้น 24 วิวแม่น้ำเจ้าพระยา ฝั่งนนทบุรี ตกแต่ง Full Built-in ระเบียงกว้าง วิวสะพาน วัดเก่า ใกล้ท่าเรือนนทบุรี MRT บางซ่อน Riparian Resort-Style Amenities',
 'a2',ARRAY['https://images.unsplash.com/photo-1560448205-4d0b7db08ede?w=800','https://images.unsplash.com/photo-1591474200742-8e512e6f98f8?w=800','https://images.unsplash.com/photo-1534430480882-96c9102bcf71?w=800','https://images.unsplash.com/photo-1416331108676-a22ccb276e35?w=800','https://images.unsplash.com/photo-1556020685-ae41abfc9365?w=800'],
 '2026-07-16'),

('p112','คอนโด 3 ห้องนอน ใหม่ ใกล้สนามบินสมุย','คอนโด','สุราษฎร์ธานี','เกาะสมุย สุราษฎร์ธานี',
 12500000,'BUY',3,3,110,0,0,6,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโด 3 ห้องนอน Low-Rise สไตล์ Tropical ใกล้สนามบินสมุย วิวสวนมะพร้าว สระว่ายน้ำ ฟิตเนส เหมาะพักอาศัยและ Holiday Home ปล่อยเช่า AirBnB คาด Yield 8-10% ต่อปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-07-17'),

('p113','คอนโดให้เช่า ย่านรัชดา ฟ้า ใกล้ MRT ลาดพร้าว','คอนโด','กรุงเทพฯ','รัชดาภิเษก-ลาดพร้าว กรุงเทพฯ',
 15000,'RENT',1,1,32,0,0,6,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','ทีวี','เครื่องซักผ้า'],FALSE,FALSE,
 'คอนโด 1 ห้องนอน ให้เช่า เฟอร์นิเจอร์ครบ ชั้น 6 ใกล้ MRT ลาดพร้าว ห้างเซ็นทรัล ลาดพร้าว The Mall บางกะปิ เหมาะมนุษย์เงินเดือน ราคาคุ้มค่าย่านนี้',
 'a2',ARRAY['https://images.unsplash.com/photo-1582719508491-a3a1e6b7e0e0?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800','https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800','https://images.unsplash.com/photo-1560185008-b033106af5c3?w=800','https://images.unsplash.com/photo-1463453091185-61582044d556?w=800'],
 '2026-07-18'),

('p114','คอนโด Penthouse 2 ชั้น วิวดอย เชียงราย','คอนโด','เชียงราย','เมือง เชียงราย',
 8900000,'BUY',3,3,180,0,0,25,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'Penthouse Duplex ชั้น 24-25 วิวดอยตุง ดอยแม่สลอง พาโนราม่า เมืองเชียงราย ห้องนอน 3 ห้อง ระเบียงส่วนตัว ตกแต่งหรู Chef Kitchen ใกล้สนามบินเชียงราย เหมาะผู้บริหารและนักลงทุน',
 'a6',ARRAY['https://images.unsplash.com/photo-1617325247661-675ab4b64ae2?w=800','https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800','https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800','https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800','https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=800'],
 '2026-07-19'),

('p115','คอนโดให้เช่า Hua Hin Sea View ชั้น 14','คอนโด','ประจวบคีรีขันธ์','หัวหิน ประจวบคีรีขันธ์',
 32000,'RENT',2,2,68,0,0,14,1,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','ทีวี'],FALSE,TRUE,
 'คอนโด 2 ห้องนอน ชั้น 14 วิวทะเลหัวหิน เฟอร์นิเจอร์ครบ ให้เช่ารายเดือน สระว่ายน้ำดาดฟ้า ฟิตเนส ใกล้ตลาดหัวหิน ถนนนเรศดำริห์ เหมาะ Long Stay ผู้เกษียณชาวต่างชาติ',
 'a3',ARRAY['https://images.unsplash.com/photo-1540519338287-7c3f9a68ac3d?w=800','https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800','https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?w=800','https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800','https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800'],
 '2026-07-20'),

-- ══════════════════════════════════════════════════════════════
-- ทาวน์โฮม (p116–p121)
-- ══════════════════════════════════════════════════════════════
('p116','ทาวน์โฮม 3 ชั้น ใกล้รถไฟฟ้าสายสีเขียว บางซื่อ','ทาวน์โฮม','กรุงเทพฯ','บางซื่อ-เตาปูน กรุงเทพฯ',
 5500000,'BUY',3,3,185,26,3,0,2,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,FALSE,
 'ทาวน์โฮม 3 ชั้น ห่างสถานีกลางบางซื่อ 1 กม. ใกล้ MRT เตาปูน 3 ห้องนอน 3 ห้องน้ำ พื้นที่ใช้สอย 185 ตร.ม. ที่จอดรถ 2 คัน ทำเลอนาคตไกล ราคายังไม่ขึ้นเต็มที่',
 'a1',ARRAY['https://images.unsplash.com/photo-1616046229478-9901369b4cc5?w=800','https://images.unsplash.com/photo-1567767292278-d3ea68e2c6a2?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800','https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800'],
 '2026-07-21'),

('p117','ทาวน์โฮมให้เช่า 3 ชั้น เชียงใหม่ ย่านสันทราย','ทาวน์โฮม','เชียงใหม่','สันทราย เชียงใหม่',
 16000,'RENT',3,2,145,20,3,0,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า'],TRUE,FALSE,
 'ทาวน์โฮม 3 ชั้น ให้เช่า ย่านสันทราย เชียงใหม่ ใกล้ PROMENADA Resort Mall นิคมอุตสาหกรรมภาคเหนือ ตกแต่งบางส่วน รับสัตว์เลี้ยง เหมาะพนักงานนิคมและครอบครัว',
 'a6',ARRAY['https://images.unsplash.com/photo-1599427303058-f04cbcf4756f?w=800','https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800','https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=800','https://images.unsplash.com/photo-1467533003447-e295ff1b0435?w=800'],
 '2026-07-22'),

('p118','ทาวน์โฮม 2 ชั้น ราคาดี ชลบุรี ใกล้ Central','ทาวน์โฮม','ชลบุรี','เมือง ชลบุรี',
 2200000,'BUY',3,2,120,20,2,0,1,'none',FALSE,
 ARRAY['แอร์'],FALSE,FALSE,
 'ทาวน์โฮม 2 ชั้น ราคาจับต้องได้ ใกล้ห้าง Central ชลบุรี โรงพยาบาลชลบุรี 3 ห้องนอน 2 ห้องน้ำ ที่จอดรถ 1 คัน เหมาะครอบครัวรุ่นใหม่ที่ทำงานในชลบุรีและ EEC',
 'a5',ARRAY['https://images.unsplash.com/photo-1600566752447-b00f67e74a0e?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800','https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800','https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800'],
 '2026-07-23'),

('p119','ทาวน์โฮม Premium ใกล้ BTS ราษฎร์บูรณะ','ทาวน์โฮม','กรุงเทพฯ','ราษฎร์บูรณะ-พระราม 3 กรุงเทพฯ',
 6800000,'BUY',3,3,210,30,3,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า'],FALSE,TRUE,
 'ทาวน์โฮม 3 ชั้น Premium ย่านราษฎร์บูรณะ 3 ห้องนอน 3 ห้องน้ำ ดาดฟ้าส่วนตัว ตกแต่ง Full Built-in ทั้งหลัง ใกล้ BTS สาย Extension เปิดใหม่ ห้าง IKEA ราษฎร์บูรณะ ทำเลดีมาก',
 'a1',ARRAY['https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=800','https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?w=800','https://images.unsplash.com/photo-1565372195458-cf3eced61daf?w=800','https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800','https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800'],
 '2026-07-24'),

('p120','ทาวน์โฮมให้เช่า ใกล้นิคม Rojana อยุธยา','ทาวน์โฮม','พระนครศรีอยุธยา','อุทัย โรจนะ พระนครศรีอยุธยา',
 10000,'RENT',2,1,100,16,2,0,1,'partial',TRUE,
 ARRAY['แอร์','ตู้เย็น'],TRUE,FALSE,
 'ทาวน์โฮม 2 ชั้น ให้เช่า ใกล้นิคมอุตสาหกรรม Rojana อยุธยา ราคาถูก เหมาะพนักงานนิคม 2 ห้องนอน 1 ห้องน้ำ ที่จอดรถ รับสัตว์เลี้ยงขนาดเล็ก สัญญา 12 เดือน',
 'a5',ARRAY['https://images.unsplash.com/photo-1484301548518-d0e0a5db0fc8?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800','https://images.unsplash.com/photo-1574691250077-03a929faece5?w=800','https://images.unsplash.com/photo-1574691250077-03a929faece5?w=800'],
 '2026-07-25'),

('p121','ทาวน์โฮม 4 ชั้น หรูมาก ย่านเอกมัย','ทาวน์โฮม','กรุงเทพฯ','เอกมัย สุขุมวิท 63 กรุงเทพฯ',
 12800000,'BUY',4,5,320,36,4,0,2,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม'],FALSE,TRUE,
 'ทาวน์โฮม 4 ชั้น Ultra Premium ย่านเอกมัย 4 ห้องนอน 5 ห้องน้ำ ดาดฟ้า Jacuzzi ระบบ Smart Home ลิฟต์ภายใน ครัวยุโรป Built-in เต็มรูปแบบ ใกล้ BTS เอกมัย 600 เมตร ทองหล่อ Brunch Spot',
 'a1',ARRAY['https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800','https://images.unsplash.com/photo-1565372195458-cf3eced61daf?w=800','https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=800','https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?w=800','https://images.unsplash.com/photo-1599619585752-c3edb42a414c?w=800'],
 '2026-07-26'),

-- ══════════════════════════════════════════════════════════════
-- วิลล่า (p122–p125)
-- ══════════════════════════════════════════════════════════════
('p122','วิลล่าให้เช่า 4 ห้องนอน วิวทะเล เกาะพีพี','วิลล่า','กระบี่','เกาะพีพี กระบี่',
 180000,'RENT',4,4,450,200,2,0,4,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','โฮมเธียเตอร์'],FALSE,TRUE,
 'วิลล่า 2 ชั้น วิวทะเลเกาะพีพี 180 องศา สระว่ายน้ำ Infinity ริมหน้าผา Sala ริมสระ ตกแต่งหรู Chef Kitchen ให้เช่ารายเดือน เหมาะ Ultra Luxury Holiday Retreat และ Photoshoot',
 'a3',ARRAY['https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-07-27'),

('p123','Pool Villa ใหม่ กมลา ภูเก็ต ใกล้ Cafe Del Mar','วิลล่า','ภูเก็ต','กมลา ภูเก็ต',
 25000000,'BUY',4,4,500,160,2,0,3,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','สมาร์ทโฮม'],FALSE,TRUE,
 'วิลล่า Pool Villa ใหม่ปี 2025 ย่านกมลา ภูเก็ต ห่างชายหาดกมลา 300 เมตร สระว่ายน้ำ 14×4 เมตร ตกแต่งสไตล์ Modern Bali 4 ห้องนอน En-suite ทั้งหมด ระบบ Smart Home เต็มรูปแบบ Yield คาด 10-12%',
 'a3',ARRAY['https://images.unsplash.com/photo-1630699144867-37acec97df5a?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1598994942340-0a2e0e11c5bc?w=800','https://images.unsplash.com/photo-1574362848149-11496d93a5a7?w=800','https://images.unsplash.com/photo-1448630360428-65456885c650?w=800'],
 '2026-07-28'),

('p124','วิลล่าตากอากาศ ปาย แม่ฮ่องสอน วิวดอย','วิลล่า','แม่ฮ่องสอน','ปาย แม่ฮ่องสอน',
 7500000,'BUY',3,3,260,300,1,0,4,'full',TRUE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เตาผิง'],TRUE,TRUE,
 'วิลล่าสไตล์ Bohemian Chic เมืองปาย แม่ฮ่องสอน วิวทิวเขา ทุ่งนา แม่น้ำปาย อากาศเย็นสบาย เตาผิง สระน้ำร้อน รับสัตว์เลี้ยง บนที่ดิน 300 ตร.วา เหมาะ Retreat และ AirBnB Yield สูงช่วง High Season',
 'a6',ARRAY['https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800','https://images.unsplash.com/photo-1502672023488-70e25813eb80?w=800','https://images.unsplash.com/photo-1453728013993-6d66e9c9123a?w=800','https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=800'],
 '2026-07-29'),

('p125','วิลล่าให้เช่า ริมหาดเฉวง เกาะสมุย','วิลล่า','สุราษฎร์ธานี','เฉวง เกาะสมุย สุราษฎร์ธานี',
 150000,'RENT',5,5,700,300,2,0,5,'full',FALSE,
 ARRAY['แอร์','ตู้เย็น','เครื่องซักผ้า','เครื่องอบผ้า','โฮมเธียเตอร์','สมาร์ทโฮม'],FALSE,TRUE,
 'Beachfront Villa สุดหรู ริมชายหาดเฉวง เกาะสมุย 5 ห้องนอน สระว่ายน้ำ Overflow ริมทะเล Beach Club ส่วนตัว บัตเลอร์ส่วนตัว Chef Kitchen ให้เช่ารายเดือน เหมาะ Corporate Retreat และ Wedding',
 'a3',ARRAY['https://images.unsplash.com/photo-1600566752355-35792bedcfea?w=800','https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800','https://images.unsplash.com/photo-1568992687947-868a62a9f521?w=800','https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800','https://images.unsplash.com/photo-1554469384-e58fac16e23a?w=800'],
 '2026-07-30'),

-- ══════════════════════════════════════════════════════════════
-- ที่ดิน (p126–p129)
-- ══════════════════════════════════════════════════════════════
('p126','ที่ดินเปล่า 2 ไร่ ใกล้เขื่อนศรีนครินทร์ กาญจนบุรี','ที่ดิน','กาญจนบุรี','ศรีสวัสดิ์ กาญจนบุรี',
 2200000,'BUY',0,0,0,800,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดิน 2 ไร่ ริมถนนเลียบเขื่อน วิวทะเลสาบ อากาศดี เหมาะสร้างรีสอร์ทตากอากาศ บ้านพักริมน้ำ หรือแคมป์ปิ้ง โฉนดพร้อมโอน ห่างกรุงเทพฯ 130 กม. ทางถนนสาย 323 สวยมาก',
 'a5',ARRAY['https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800','https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=800'],
 '2026-07-31'),

('p127','ที่ดินพัฒนา ใกล้โรงพยาบาล บึงกุ่ม กรุงเทพฯ','ที่ดิน','กรุงเทพฯ','บึงกุ่ม-รามคำแหง กรุงเทพฯ',
 12000000,'BUY',0,0,0,220,0,0,0,'none',FALSE,ARRAY[]::TEXT[],TRUE,FALSE,
 'ที่ดิน 220 ตร.วา ย่านบึงกุ่ม ใกล้โรงพยาบาลราชบุรีกรุ๊ป ห้าง The Mall บางกะปิ เส้น MRT รามคำแหง เหมาะสร้างคลินิก ร้านขายยา อาคารพักแพทย์ หรือทาวน์โฮม',
 'a5',ARRAY['https://images.unsplash.com/photo-1558442074-3c19857bc1dc?w=800','https://images.unsplash.com/photo-1576673442511-7e39b6545c87?w=800','https://images.unsplash.com/photo-1618221381711-42ca8ab6e908?w=800','https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800'],
 '2026-08-01'),

('p128','ที่ดินทำเลทอง ริมวงแหวน มีนบุรี กรุงเทพฯ','ที่ดิน','กรุงเทพฯ','มีนบุรี-ลาดกระบัง กรุงเทพฯ',
 8500000,'BUY',0,0,0,400,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ที่ดิน 400 ตร.วา ติดถนนวงแหวนรอบนอก ย่านมีนบุรี ใกล้ MRT สายสีชมพู Lotus มีนบุรี เหมาะพัฒนาโครงการบ้านจัดสรร คลังสินค้า หรือนิคมขนาดเล็ก',
 'a5',ARRAY['https://images.unsplash.com/photo-1576673442511-7e39b6545c87?w=800','https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800','https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800','https://images.unsplash.com/photo-1497366754035-91ee15a9d7e2?w=800'],
 '2026-08-02'),

('p129','ที่ดินท่องเที่ยว ติดแหล่งน้ำ เกาะช้าง ตราด','ที่ดิน','ตราด','เกาะช้าง ตราด',
 9500000,'BUY',0,0,0,480,0,0,0,'none',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'ที่ดิน 480 ตร.วา ติดหาดทรายเกาะช้าง วิวทะเลอ่าวไทย เหมาะสร้างวิลล่า รีสอร์ท Boutique ตลาดนักท่องเที่ยวเกาะช้างกำลังบูมมาก ราคาที่ดินยังถูกกว่าภูเก็ต เกาะสมุย คาด Yield สูงมาก',
 'a3',ARRAY['https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800','https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800','https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800','https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800'],
 '2026-08-03'),

-- ══════════════════════════════════════════════════════════════
-- อาคารพาณิชย์ (p130–p133)
-- ══════════════════════════════════════════════════════════════
('p130','อาคารพาณิชย์ 3 ชั้น ใกล้ ม.มหิดล พุทธมณฑล','อาคารพาณิชย์','นครปฐม','พุทธมณฑล สาย 4 นครปฐม',
 5800000,'BUY',0,3,180,22,3,0,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'อาคารพาณิชย์ 3 ชั้น หน้ากว้าง 4.5 เมตร ใกล้มหาวิทยาลัยมหิดล ศาลายา ตลาดพุทธมณฑล เหมาะร้านอาหาร คลินิก ร้านสะดวกซื้อ ปัจจุบันปล่อยเช่า 16,000 บาท/เดือน',
 'a3',ARRAY['https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800','https://images.unsplash.com/photo-1524758631624-e2822e304c36?w=800','https://images.unsplash.com/photo-1497366754035-91ee15a9d7e2?w=800','https://images.unsplash.com/photo-1484101403633-562f891dc89a?w=800'],
 '2026-08-04'),

('p131','อาคารสำนักงานให้เช่า พื้นที่ 300 ตร.ม. อโศก','อาคารพาณิชย์','กรุงเทพฯ','อโศก-สุขุมวิท กรุงเทพฯ',
 90000,'RENT',0,4,300,0,8,5,2,'partial',FALSE,
 ARRAY['แอร์','อินเตอร์เน็ต'],FALSE,TRUE,
 'พื้นที่สำนักงานชั้น 5 ขนาด 300 ตร.ม. ใจกลางอโศก ใกล้ BTS อโศก + MRT สุขุมวิท ลิฟต์ ที่จอดรถ 2 คัน ตกแต่งบางส่วน สามารถปรับพื้นที่ได้ เหมาะบริษัท IT Startup และ Regional Office',
 'a3',ARRAY['https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800','https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=800','https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800','https://images.unsplash.com/photo-1502005097973-6a7082348e28?w=800'],
 '2026-08-05'),

('p132','ตึกแถว 3 ชั้น ย่านลำปาง ใกล้แหล่งท่องเที่ยว','อาคารพาณิชย์','ลำปาง','เมือง ลำปาง',
 2200000,'BUY',0,2,130,18,3,0,1,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'ตึกแถว 3 ชั้น หน้ากว้าง 4 เมตร ย่านใจกลางลำปาง ใกล้ถนนคนเดิน วัดพระธาตุลำปางหลวง ตลาดเจ้าก๋อง เหมาะเปิดร้านค้า ร้านอาหาร Cafe Boutique ราคาดีมาก',
 'a6',ARRAY['https://images.unsplash.com/photo-1615529328331-f8917597711f?w=800','https://images.unsplash.com/photo-1497366216548-37526070297c?w=800','https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800','https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800','https://images.unsplash.com/photo-1615571022219-eb45cf7faa9d?w=800'],
 '2026-08-06'),

('p133','อาคารพาณิชย์ 4 ชั้น ใกล้ MRT บึงกุ่ม','อาคารพาณิชย์','กรุงเทพฯ','บึงกุ่ม กรุงเทพฯ',
 9500000,'BUY',0,4,220,24,4,0,2,'none',FALSE,ARRAY[]::TEXT[],FALSE,FALSE,
 'อาคารพาณิชย์ 4 ชั้น หน้ากว้าง 5 เมตร ย่านบึงกุ่ม ใกล้ MRT สายสีส้มที่กำลังเปิดใหม่ ไฟฟ้า 3 เฟส ลิฟต์ เหมาะสำนักงาน คลินิก หอพัก ปัจจุบันว่าง พร้อมโอน',
 'a3',ARRAY['https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=800','https://images.unsplash.com/photo-1587293852726-70cdb56c2866?w=800','https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800','https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800','https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800'],
 '2026-08-07'),

-- ══════════════════════════════════════════════════════════════
-- รีสอร์ท & โรงแรม (p134–p135)
-- ══════════════════════════════════════════════════════════════
('p134','รีสอร์ท 8 ห้อง ริมแม่น้ำ กาญจนบุรี','รีสอร์ท','กาญจนบุรี','ไทรโยค กาญจนบุรี',
 22000000,'BUY',8,8,800,1200,1,0,20,'full',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'รีสอร์ทริมแม่น้ำแควน้อย 8 บังกะโล ริมน้ำ วิวธรรมชาติ ภูเขา ป่า แพริมน้ำ ร้านอาหาร Kayak และ Raft รายได้ดีช่วง High Season Occupancy 70-85% เหมาะนักลงทุนที่รักธรรมชาติ',
 'a3',ARRAY['https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1448630360428-65456885c650?w=800','https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800','https://images.unsplash.com/photo-1556804335-2fa563e93aae?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800'],
 '2026-08-08'),

('p135','โรงแรม Design Hotel 25 ห้อง ย่านเจริญกรุง','โรงแรม','กรุงเทพฯ','เจริญกรุง-ตลาดน้อย กรุงเทพฯ',
 68000000,'BUY',25,25,1600,180,5,0,8,'full',FALSE,ARRAY[]::TEXT[],FALSE,TRUE,
 'โรงแรม Design Boutique 5 ชั้น 25 ห้อง ย่านเจริญกรุง-ตลาดน้อย สไตล์ Sino-Portuguese Rooftop Bar ร้านอาหาร Lobby Gallery พร้อม License โรงแรม Occupancy 82% รายได้สุทธิ 6+ ล้านบาท/ปี คาดคืนทุน 10 ปี',
 'a3',ARRAY['https://images.unsplash.com/photo-1560250097-0dc05ae8aedf?w=800','https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=800','https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800','https://images.unsplash.com/photo-1613545325268-2f15f20d2670?w=800','https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=800'],
 '2026-08-09')

ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- อัปเดต prop_ids ของ agents (เพิ่ม p96–p135)
-- ============================================================
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p96','p97','p98','p99','p116','p119','p121']) WHERE id = 'a1';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p104','p105','p106','p108','p110','p111','p113']) WHERE id = 'a2';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p103','p109','p112','p114','p115','p122','p123','p125','p129','p130','p131','p133','p134','p135']) WHERE id = 'a3';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p101','p107','p118','p120']) WHERE id = 'a4';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p102','p126','p127','p128']) WHERE id = 'a5';
UPDATE agents SET prop_ids = array_cat(prop_ids, ARRAY['p100','p114','p117','p124','p132']) WHERE id = 'a6';

-- ============================================================
-- ✅ DONE — Patch v11.0
-- สรุปข้อมูลที่เพิ่มเข้ามา:
--   portfolio ใหม่  : 4  รายการ (pt09–pt12) → รวม 12 รายการ
--   services ใหม่   : 4  รายการ (pest, move, photo, legal) → รวม 10 รายการ
--   blogs ใหม่      : 4  บทความ → รวม 9 บทความ
--   properties ใหม่ : 40 รายการ (p96–p135) → รวม 135 รายการ
--     บ้านเดี่ยว    +8  (p96–p103)
--     คอนโด         +12 (p104–p115)
--     ทาวน์โฮม      +6  (p116–p121)
--     วิลล่า         +4  (p122–p125)
--     ที่ดิน          +4  (p126–p129)
--     อาคารพาณิชย์   +4  (p130–p133)
--     รีสอร์ท        +1  (p134)
--     โรงแรม         +1  (p135)
-- ============================================================
