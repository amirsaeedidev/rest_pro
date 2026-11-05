# Supabase / CRM integration

## Data used by the customer app

| Table | Fields/features | Update model |
|---|---|---|
| `banners` | `title`, `subtitle`, `promo_title`, `image_url`, `logo_url`, `discount_code`, `sort_order`, `is_active` | Realtime, active rows only |
| `categories` | `name`, `image_url`, `sort_order`, `is_active`, `loyalty_points_per_item` | Realtime |
| `products` | `name`, `description`, `about_dish`, `price`, `discounted_price`, `discount_percent`, `labels`, `image_url`, `category_id`, `rating`, `review_count`, `is_popular`, `is_active` | Realtime |
| `discounts` | CRM coupon rules | Realtime; final eligibility checked by `place_order` |
| `customer_notifications` | customer notification content/read status | User-scoped Realtime |
| `orders`, `order_items` | order headers and items | Transactional RPC + orders Realtime |
| `restaurant_settings` | delivery fee and minimum order amount | Realtime |
| `restaurant_tables` | active, unoccupied tables | Realtime |
| `addresses`, `profiles`, `loyalty_wallets`, `tickets`, `ticket_messages` | customer features | Scoped queries and Realtime where implemented |

## Existing database checks

`banners` already contains the banner fields listed above. `customer_notifications` already contains `user_id`, `title`, `body`, `notification_type`, `is_read`, `read_at`, and timestamps. The relevant tables already belong to `supabase_realtime`. Existing RLS allows public reads only for active banners and limits customer notification reads/updates to rows where `auth.uid() = user_id`. No DDL was applied by this source update.

## Operational notes

- Add/manage banners, categories and products in the CRM. The app intentionally does not seed mock content.
- Images must use publicly readable HTTPS URLs or storage policies that permit fetching from the customer app.
- Account-specific rows require the existing Supabase Auth session. The OTP UI was intentionally left untouched; the current development login must create the configured Supabase session for orders, addresses and notifications to work.
- `place_order` returns a UUID rather than a full order row. The app now treats it as an ID, then reads the saved order when accessible.
- Payment is simulation-only. The app does not call a real payment gateway.
