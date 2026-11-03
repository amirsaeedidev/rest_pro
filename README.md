# اپلیکیشن مشتری رستوران — نسخه یکپارچه با CRM

این پروژه Flutter به همان پروژه Supabase متصل می‌شود که CRM رستوران از آن استفاده می‌کند.

## تنظیم اتصال Supabase

فایل `.env` دیگر استفاده یا commit نمی‌شود. تنظیمات Supabase در زمان اجرا/Build از طریق Dart defines تزریق می‌شوند.

در سیستم توسعه، مقادیر را از داشبورد Supabase بردارید و اجرا کنید:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

برای ساخت محلی:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

هرگز کلید `service_role` یا کلید مخفی سرور را در Flutter یا فایل‌های قابل دانلود اپ قرار ندهید. اپ Flutter یک کلاینت عمومی است؛ دسترسی داده‌ها باید با RLS و کلید عمومی Supabase محافظت شود.

## تنظیم GitHub Actions

در Repository به مسیر **Settings → Secrets and variables → Actions → New repository secret** بروید و دو Secret بسازید:

- `SUPABASE_URL`: آدرس پروژه Supabase
- `SUPABASE_ANON_KEY`: کلید عمومی Publishable یا legacy anon همان پروژه

Workflow با هر push و Pull Request به `main`، وابستگی‌ها را دریافت می‌کند، `flutter analyze` و `flutter test` را اجرا می‌کند و APK و AAB می‌سازد. خروجی‌ها در بخش **Actions → اجرای Workflow → Artifacts** قابل دانلود هستند.

## اتصال‌های فعال

- `banners`: بنرها و کدهای تخفیف از CRM خوانده می‌شوند.
- `categories` و `products`: دسته‌ها و محصولات از دیتابیس خوانده می‌شوند.
- `discounts`: فهرست تخفیف‌ها به‌صورت Realtime به‌روزرسانی می‌شود.
- `customer_notifications`: اعلان‌ها با به‌روزرسانی زنده.
- `orders` و `order_items`: ثبت سفارش با RPC تراکنشی `place_order`.
- `restaurant_settings` و `restaurant_tables`: تنظیمات رستوران و میزها از CRM.
- `addresses`, `profiles`, `loyalty_wallets`, `tickets`, `ticket_messages`: اطلاعات حساب مشتری.

## رفتارهای عمداً آزمایشی

- ورود و OTP همان پیاده‌سازی قبلی است و تغییری نکرده است.
- پرداخت فقط رابط آزمایشی «پرداخت موفق» دارد؛ درگاه بانکی واقعی فراخوانی نمی‌شود.