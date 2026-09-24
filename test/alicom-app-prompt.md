# Prompt — Alicom app-এ product ও category দেখানো

(নিচের পুরোটা কপি করে app-এর project-এ পেস্ট করো)

---

Alicom নামে একটা e-commerce backend চলছে। সেটার catalog API থেকে category আর
product এনে app-এ দেখাতে হবে। Backend-এ কোনো পরিবর্তন করার দরকার নেই — শুধু app
থেকে API কল করতে হবে।

## Base URL

```
http://192.168.0.65:8000/api
```

- আসল ফোনে (একই WiFi): উপরেরটাই
- Android emulator: `http://10.0.2.2:8000/api`
- iOS Simulator: `http://localhost:8000/api`

পোর্ট **8000**, 8001 নয়। এটা যেন একটা জায়গায় config হিসেবে থাকে, হার্ডকোড করা না
থাকে — LAN IP রাউটার রিস্টার্টে বদলায়। HTTP (HTTPS নয়), তাই Android-এ
`usesCleartextTraffic` আর iOS-এ ATS exception লাগবে dev build-এ।

## Response খাম

প্রতিটা response এরকম:

```json
{ "message": "Products fetched successfully.", "data": { ... } }
```

আসল জিনিস সবসময় `data` এর ভেতরে।

## Endpoints

### GET /products — product তালিকা

```json
{
  "data": {
    "products": [ ...product card... ],
    "pagination": {
      "current_page": 1, "per_page": 20, "total": 32,
      "last_page": 2, "from": 1, "to": 20, "has_more_pages": true
    }
  }
}
```

Query parameter (সবগুলো optional):

| param | উদাহরণ | কাজ |
|---|---|---|
| `page` | `2` | পেজ নম্বর |
| `per_page` | `50` | সর্বোচ্চ 100 |
| `category_slug` | `speakers` | category দিয়ে ফিল্টার |
| `brand_slug[]` | `brand_slug[]=apple` | array, একাধিক দেওয়া যায় |
| `search` | `speaker` | নাম দিয়ে খোঁজা |
| `min_price` / `max_price` | `1000` | দামের রেঞ্জ |
| `in_stock` | `true` | শুধু স্টকে আছে এমন |
| `is_new` / `is_feature` / `is_best_seller` | `true` | ফ্ল্যাগ |
| `sort` | — | নিচের সতর্কতা দেখো |

### GET /products/{slug} — product detail

`data` এর ভেতরে তিনটা key: `product`, `reviews`, `related_products`।

### GET /categories — category তালিকা

Array of:

```json
{
  "name": "Mobile Phones",
  "slug": "mobile-phones",
  "img": "http://192.168.0.65:8000/dummy/images/demo/phone-iphone-15.webp",
  "total_product": 3,
  "is_featured": true,
  "show_in_menu": false,
  "parent_slug": "electronics",
  "parent_name": "Electronics",
  "is_subcategory": true
}
```

`parent_slug` / `is_subcategory` দিয়ে দুই স্তরের গাছ বানানো যায়।

### অন্যান্য কাজে লাগতে পারে

`/home/fetch-data`, `/banners`, `/hero-banners`, `/brands`, `/flash-sales`,
`/footer`, `/blog-posts`, `/delivery-zones`

## Product card-এর field

```
id, slug, name, short_description, sku, tags
images (array of absolute URL), image_alt_text, image_alt_texts, images_with_alt
category_name, brand_name, unit, unit_short_code, weight
price, original_price, discount_price, discount_type, discount_label
average_rating, stock_quantity, in_stock
is_new, is_feature, is_best_seller, is_wishlisted, position, updated_at
```

Detail-এ বাড়তি: `description`, `description_html`, `category_slug`,
`brand_slug`, `variants`, `has_variants`, `total_reviews`, `pre_order`,
`video_url`, `video_embed_url`, `meta_title`, `meta_description`, `can_review`।

## যেসব জায়গায় ভুল হওয়ার সম্ভাবনা বেশি

1. **Product-এর নাম `name`, `title` নয়।** DB-তে কলামটার নাম `title`, কিন্তু API
   `name` দিয়ে পাঠায়। `title` ধরে নিলে চুপচাপ `null` আসবে, error দেবে না।

2. **Category filter-এর param `category_slug`, `category` নয়।** ভুল নাম দিলে
   Laravel সেটা উপেক্ষা করে **সব product** ফেরত দেয় — error নেই, তাই ফিল্টার
   ভেঙে আছে বোঝা কঠিন। ফিল্টার করার পর `pagination.total` কমেছে কিনা দেখে নিও।

3. **Pagination ডিফল্ট ২০।** মোট 32টা product, তাই প্রথম পেজে সব আসবে না।
   হয় `per_page` বাড়াও, নয় `has_more_pages` দেখে পরের পেজ আনো।

4. **`price` মানে ছাড়ের পরের দাম।** `original_price` হলো ছাড়ের আগের। কাটা দাগ
   দিতে হলে `original_price` দেখাবে, আর `discount_label` এ "10% OFF" রেডি আছে।

5. **`images` এ পুরো absolute URL থাকে**, base URL আবার জোড়া দিও না।

6. **`sort` এর মান নির্দিষ্ট তালিকার বাইরে দিলে 422 আসে** (অন্য param গুলোর মতো
   চুপ করে থাকে না)। বৈধ মান জানতে
   `ProductRepository::STOREFRONT_SORTS` দেখতে হবে, অথবা `sort` বাদ দাও।

## এখন catalog-এ যা আছে

মোট **19টা category**, **32টা product**।

- Electronics › Mobile Phones, Laptops, Audio (› Headphones, Speakers), Wearables
- Home Appliances
- Fashion › T-Shirts
- Books › Fiction, Non-Fiction
- Kitchen Appliances › Blenders & Grinders, Microwaves & Ovens
- Cooling & Climate › Fans, Refrigerators

**সতর্কতা:** `/categories` endpoint টা Kitchen Appliances, Cooling & Climate,
Electronics, Fashion, Books — এই top-level parent গুলো **ফেরত দেয় না**, কারণ
ওদের নিজেদের সরাসরি কোনো product নেই। ফেরত আসা 14টা মূলত leaf category। পুরো
গাছ দেখাতে চাইলে প্রতিটা item-এর `parent_slug` / `parent_name` থেকে parent
গুলো নিজে বানিয়ে নিতে হবে।

## কাজটা

1. Base URL একটা জায়গায় config করো।
2. Response খাম (`data`) খোলার জন্য একটা ছোট API client লেখো, timeout আর
   network error হ্যান্ডলিং সহ।
3. Product ও Category-র জন্য model/type লেখো — উপরের field নাম হুবহু মেনে।
4. Category তালিকার screen — `img` সহ, দুই স্তরের গাছ হিসেবে।
5. Product তালিকার screen — pagination সহ, `category_slug` দিয়ে ফিল্টার।
6. Product detail screen — ছবি, দাম (ছাড় সহ), description, স্টক।

শেষে সত্যিকারের API কল করে যাচাই করো যে 32টা product আর 19টা category-ই আসছে —
ডামি ডেটা দিয়ে নয়।
