-- =====================================================
-- MATCHDOOR DATABASE SCHEMA v2
-- Tables: properties, agents, portfolio, services,
--         blogs, listings, buy_requests
-- =====================================================

-- 1. AGENTS (ต้องสร้างก่อน เพราะ properties อ้างอิง)
CREATE TABLE agents (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  title       TEXT,
  phone       TEXT,
  line_id     TEXT,
  bio         TEXT,
  avatar_color TEXT DEFAULT '#0f3460'
);

INSERT INTO agents VALUES
  ('a1', 'สมชาย มั่นคง',   'ผู้จัดการฝ่ายขาย',           '081-234-5678', '@somchai', 'ประสบการณ์ 10 ปี ด้านอสังหาริมทรัพย์', '#0f3460'),
  ('a2', 'วารี สุขสันต์',  'ที่ปรึกษาอสังหาริมทรัพย์',    '082-345-6789', '@waree',   'เชี่ยวชาญคอนโดและทาวน์โฮม',           '#00b894'),
  ('a3', 'ประภัส รุ่งเรือง','ผู้เชี่ยวชาญที่ดิน',           '083-456-7890', '@praphat', 'เชี่ยวชาญที่ดิน ภาคตะวันออก',          '#6c5ce7'),
  ('a4', 'ณัฐธิดา ใจดี',   'ที่ปรึกษา Luxury',             '084-567-8901', '@nuttida', 'เชี่ยวชาญบ้านหรู High-end',             '#e17055');

-- 2. PROPERTIES (อสังหาริมทรัพย์)
CREATE TABLE properties (
  id          SERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  type        TEXT NOT NULL,
  province    TEXT,
  location    TEXT,
  price       INTEGER,
  transaction TEXT CHECK (transaction IN ('BUY','RENT')),
  bedrooms    INTEGER DEFAULT 0,
  bathrooms   INTEGER DEFAULT 0,
  area        INTEGER,
  description TEXT,
  is_new      BOOLEAN DEFAULT FALSE,
  is_recommend BOOLEAN DEFAULT FALSE,
  agent_id    TEXT REFERENCES agents(id) ON DELETE SET NULL,
  photos      TEXT[] DEFAULT '{}',
  created_at  TIMESTAMP DEFAULT NOW()
);

INSERT INTO properties (title, type, province, location, price, transaction, bedrooms, bathrooms, area, description, is_new, is_recommend, agent_id, photos, created_at) VALUES
  ('บ้านเดี่ยว 2 ชั้น หมู่บ้านพฤกษา', 'บ้านเดี่ยว', 'กรุงเทพฯ', 'ลาดกระบัง กรุงเทพฯ', 4500000, 'BUY',  3, 2, 180, 'บ้านเดี่ยว 2 ชั้น ทำเลดี ใกล้ทางด่วน',      TRUE,  TRUE,  'a1', ARRAY['https://picsum.photos/id/101/800/600','https://picsum.photos/id/111/800/600'], '2025-04-20'),
  ('คอนโด ลุมพินี วิลล์ รัชโยธิน',    'คอนโด',    'กรุงเทพฯ', 'จตุจักร กรุงเทพฯ',    2200000, 'BUY',  1, 1,  35, 'คอนโดใกล้รถไฟฟ้า BTS พร้อมอยู่',            FALSE, TRUE,  'a1', ARRAY['https://picsum.photos/id/102/800/600'], '2025-03-15'),
  ('ทาวน์โฮม 3 ชั้น ใกล้รถไฟฟ้าสายสีม่วง','ทาวน์โฮม','นนทบุรี', 'ปากเกร็ด นนทบุรี',    3200000, 'BUY',  3, 2, 140, 'โครงการใหม่ ใกล้ MRT สายสีม่วง',            TRUE,  FALSE, 'a2', ARRAY['https://picsum.photos/id/103/800/600'], '2025-05-01'),
  ('ที่ดินเปล่า ติดถนนใหญ่ ทำเลทอง',   'ที่ดิน',   'ชลบุรี',   'บางละมุง ชลบุรี',     8900000, 'BUY',  0, 0, 400, 'ที่ดินเปล่า ติดถนน 4 เลน เหมาะลงทุน',       FALSE, TRUE,  'a3', ARRAY['https://picsum.photos/id/104/800/600'], '2025-02-10'),
  ('คอนโดให้เช่า แอชตัน อโศก',          'คอนโด',    'กรุงเทพฯ', 'อโศก กรุงเทพฯ',        35000, 'RENT', 2, 2,  65, 'คอนโดหรู ใจกลางเมือง ใกล้ BTS อโศก',        FALSE, TRUE,  'a4', ARRAY['https://picsum.photos/id/105/800/600'], '2025-04-01');

-- 3. PORTFOLIO (ผลงานปิดการขาย/เช่า)
CREATE TABLE portfolio (
  id          SERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  type        TEXT,
  price       INTEGER,
  status      TEXT CHECK (status IN ('SOLD','RENTED')),
  location    TEXT,
  closed_date TEXT,
  review      TEXT,
  photo       TEXT
);

INSERT INTO portfolio (title, type, price, status, location, closed_date, review) VALUES
  ('บ้านเดี่ยว ร่มเกล้า กรุงเทพฯ',  'บ้านเดี่ยว', 3800000, 'SOLD',   'ร่มเกล้า กรุงเทพฯ',       'ม.ค. 2568', 'บริการดีมาก โอนได้เร็ว'),
  ('คอนโด เดอะ ลาม คาราฟ',          'คอนโด',      1900000, 'SOLD',   'อ่อนนุช กรุงเทพฯ',         'ก.พ. 2568', 'ขายได้เร็วมาก ราคาดีกว่าที่คิด'),
  ('ทาวน์โฮม ศุภาลัย บางพลี',        'ทาวน์โฮม',   2600000, 'SOLD',   'บางพลี สมุทรปราการ',       'ก.พ. 2568', 'ช่วยจัดการเรื่องกู้ได้เลย ประทับใจ'),
  ('คอนโดให้เช่า สาทร',              'คอนโด',        22000, 'RENTED', 'สาทร กรุงเทพฯ',            'มี.ค. 2568', 'หาผู้เช่าได้ภายใน 2 สัปดาห์'),
  ('บ้านเดี่ยว พระราม 2',            'บ้านเดี่ยว', 5200000, 'SOLD',   'พระราม 2 กรุงเทพฯ',        'มี.ค. 2568', 'ขายได้ราคาดีมาก เกินความคาดหมาย');

-- 4. SERVICES (บริการ)
CREATE TABLE services (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  icon        TEXT,
  description TEXT,
  full_desc   TEXT,
  price       TEXT,
  duration    TEXT
);

INSERT INTO services VALUES
  ('ac',    'ล้างแอร์',            'fa-wind',        'ล้างแอร์ทุกประเภท',      'บริการล้างแอร์ทุกประเภท ทั้งแอร์บ้านและแอร์สำนักงาน ใช้สารเคมีที่เป็นมิตรต่อสิ่งแวดล้อม รับประกันงาน 30 วัน', '450 บาท/ตัว',  '1-2 ชั่วโมง'),
  ('maid',  'แม่บ้าน',             'fa-broom',       'บริการแม่บ้านคุณภาพ',    'บริการแม่บ้านคุณภาพ ผ่านการอบรมและตรวจสอบประวัติ มีทั้งรายวัน รายสัปดาห์ และรายเดือน',                        '500 บาท/วัน', 'ตามตกลง'),
  ('furn',  'ซ่อมเฟอร์นิเจอร์',   'fa-couch',       'ซ่อมเฟอร์นิเจอร์ทุกชนิด','ซ่อมเฟอร์นิเจอร์ทุกชนิด โต๊ะ เก้าอี้ ตู้ เตียง พร้อมเปลี่ยนอุปกรณ์ใหม่',                                   '300 บาท',     '1-3 ชั่วโมง'),
  ('plumb', 'แก้ไขระบบประปา',     'fa-wrench',      'แก้ไขปัญหาท่อรั่ว',      'แก้ไขปัญหาท่อรั่ว อุดตัน เปลี่ยนวาล์ว ติดตั้งระบบประปาใหม่',                                                   '500 บาท',     '1-2 ชั่วโมง'),
  ('elec',  'ซ่อมอุปกรณ์ไฟฟ้า',  'fa-bolt',        'ซ่อมไฟฟ้าภายในบ้าน',     'ซ่อมไฟฟ้าภายในบ้าน เดินสายใหม่ เปลี่ยนสวิตช์ ปลั๊ก ระบบไฟส่องสว่าง',                                         '400 บาท',     '1-3 ชั่วโมง'),
  ('door',  'เปลี่ยนลูกบิดประตู', 'fa-door-closed', 'เปลี่ยนลูกบิดทุกแบบ',    'เปลี่ยนลูกบิดประตูทุกแบบ ทั้งแบบธรรมดาและแบบดิจิตอล พร้อมติดตั้ง',                                             '250 บาท',     '30-60 นาที');

-- 5. BLOGS (บทความ)
CREATE TABLE blogs (
  id       SERIAL PRIMARY KEY,
  title    TEXT NOT NULL,
  category TEXT,
  date     TEXT,
  icon     TEXT,
  color    TEXT,
  content  TEXT
);

INSERT INTO blogs (title, category, date, icon, color, content) VALUES
  ('5 ทำเลทองที่น่าลงทุนปี 2568',            'การลงทุน',  '15 พ.ค. 2568', '🏆', 'linear-gradient(135deg,#667eea,#764ba2)', 'บทความนี้กำลังอยู่ในระหว่างการเขียน...'),
  ('วิธีเลือกคอนโดใกล้รถไฟฟ้าให้คุ้มค่า',    'คำแนะนำ',   '10 พ.ค. 2568', '🚇', 'linear-gradient(135deg,#f093fb,#f5576c)', 'บทความนี้กำลังอยู่ในระหว่างการเขียน...'),
  ('ขั้นตอนกู้สินเชื่อบ้านสำหรับมือใหม่',    'สาระน่ารู้', '5 พ.ค. 2568',  '🏦', 'linear-gradient(135deg,#4facfe,#00f2fe)', 'บทความนี้กำลังอยู่ในระหว่างการเขียน...'),
  ('เปรียบเทียบ บ้านเดี่ยว vs ทาวน์โฮม',     'คำแนะนำ',   '1 พ.ค. 2568',  '🔍', 'linear-gradient(135deg,#43e97b,#38f9d7)', 'บทความนี้กำลังอยู่ในระหว่างการเขียน...');

-- 6. LISTINGS (ฝากทรัพย์ — ต้องการ auth)
CREATE TABLE listings (
  id            SERIAL PRIMARY KEY,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name          TEXT,
  phone         TEXT,
  property_type TEXT,
  price         INTEGER,
  province      TEXT,
  transaction   TEXT CHECK (transaction IN ('ขาย','เช่า')),
  details       TEXT,
  photos        TEXT[],
  status        TEXT DEFAULT 'รอตรวจสอบ',
  created_at    TIMESTAMP DEFAULT NOW()
);

-- 7. BUY_REQUESTS (ฝากความต้องการซื้อ — ต้องการ auth)
CREATE TABLE buy_requests (
  id            SERIAL PRIMARY KEY,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name          TEXT,
  phone         TEXT,
  line_id       TEXT,
  property_type TEXT,
  budget        INTEGER,
  province      TEXT,
  transaction   TEXT CHECK (transaction IN ('ซื้อ','เช่า')),
  details       TEXT,
  status        TEXT DEFAULT 'ใหม่',
  created_at    TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================
ALTER TABLE properties   ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents       ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio    ENABLE ROW LEVEL SECURITY;
ALTER TABLE services     ENABLE ROW LEVEL SECURITY;
ALTER TABLE blogs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE buy_requests ENABLE ROW LEVEL SECURITY;

-- Public read (ทุกคนอ่านได้)
CREATE POLICY "public_read_properties" ON properties   FOR SELECT USING (true);
CREATE POLICY "public_read_agents"     ON agents       FOR SELECT USING (true);
CREATE POLICY "public_read_portfolio"  ON portfolio    FOR SELECT USING (true);
CREATE POLICY "public_read_services"   ON services     FOR SELECT USING (true);
CREATE POLICY "public_read_blogs"      ON blogs        FOR SELECT USING (true);

-- Authenticated users: insert only
CREATE POLICY "auth_insert_listings"      ON listings     FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "auth_insert_buy_requests"  ON buy_requests FOR INSERT TO authenticated WITH CHECK (true);

-- Authenticated users: view own records only
CREATE POLICY "auth_own_listings"      ON listings     FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "auth_own_buy_requests"  ON buy_requests FOR SELECT TO authenticated USING (user_id = auth.uid());
