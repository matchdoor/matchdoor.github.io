// sw.js — Matchdoor SPA Service Worker
// วัตถุประสงค์: intercept navigation request ที่เป็น SPA route ทั้งหมด
// ส่ง index.html กลับแทน ป้องกันไม่ให้ GitHub Pages แสดง 404.html
// ────────────────────────────────────────────────────────────────
const SW_VERSION = 'v1';
const CACHE_NAME = 'matchdoor-shell-' + SW_VERSION;

// รายชื่อ path ที่เป็น SPA page ทั้งหมด
const SPA_ROUTES = [
  '/listings',
  '/agents',
  '/portfolio',
  '/favorites',
  '/careers',
  '/buy',
  '/rent',
];

// ────── Install: cache index.html ──────────────────────────────
self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.add('/');
    }).then(function() {
      return self.skipWaiting();
    })
  );
});

// ────── Activate: ลบ cache เก่า ────────────────────────────────
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(k) { return k !== CACHE_NAME; })
            .map(function(k) { return caches.delete(k); })
      );
    }).then(function() {
      return self.clients.claim();
    })
  );
});

// ────── Fetch: intercept navigation ────────────────────────────
self.addEventListener('fetch', function(event) {
  var req = event.request;

  // เฉพาะ GET navigation request (ผู้ใช้พิมพ์ URL หรือ refresh) เท่านั้น
  if(req.method !== 'GET') return;
  if(req.mode !== 'navigate') return;

  var url = new URL(req.url);

  // เช็คว่าเป็น SPA route หรือ /property/... หรือไม่
  var isSpaRoute = SPA_ROUTES.indexOf(url.pathname) !== -1
    || url.pathname.startsWith('/property/');

  if(!isSpaRoute) return; // ปล่อยผ่านตามปกติ — ไม่ใช่ SPA route

  // SPA route → ส่ง index.html กลับทันที จาก cache หรือ network
  event.respondWith(
    caches.match('/').then(function(cached) {
      if(cached) return cached;
      // ถ้า cache ยังไม่มี → fetch จาก network แล้ว cache ไว้
      return fetch('/').then(function(resp) {
        var clone = resp.clone();
        caches.open(CACHE_NAME).then(function(cache) {
          cache.put('/', clone);
        });
        return resp;
      });
    }).catch(function() {
      // network ล้มเหลว → fallback fetch โดยตรง
      return fetch('/');
    })
  );
});
