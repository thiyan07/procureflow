# Notifications — ProcureFlow Real FCM + DB (2026-09-19)

**Backend:** `app/integrations/firebase/fcm_service.py` `mock [FCM-MOCK]` if `FCM_PROJECT_ID/CLIENT_EMAIL/PRIVATE_KEY` empty else `firebase-admin` `credentials.Certificate` `firebase_admin.initialize_app` `messaging.send` | **Flutter:** `core/notifications/fcm_service.dart` `firebase_messaging` `getToken` `onMessage` `onMessageOpenedApp` `notification_router.dart` | **DB:** `notifications` `device_tokens`.

## FCM Configuration

- `.env` `fcm_project_id` `fcm_client_email` `fcm_private_key` escaped `\n` — **not committed** `backend/.env.example` empty `FCM_PROJECT_ID=`.
- `fcm_service.py` `if not fcm_project_id or not fcm_client_email or not fcm_private_key: log.info FCM not configured - running in mock mode` `return mock success` `log.info [FCM-MOCK] to=... title=...`.
- `fcm_service.dart` `if (DemoConfig.useMockBackend && kDebugMode) debugPrint [FCM] Mock mode - skipping native init _token=mock_fcm_token_...` else `try Firebase.initializeApp` `getToken` else fallback `mock`.

## Device Token Management

- Flutter `FcmService.init()` `getToken` `mock_fcm_token_{ms}` if `useMockBackend` else `FirebaseMessaging.instance.getToken()` → `POST /notifications/device-token {token, platform: android/ios}` `Bearer` `device_tokens` `user_id/token/platform` dedup `token` `platform` update `user_id` `db.commit`.
- `POST /notifications/device-token` `200 {message: Token registered/Token updated, token}` `notifications.py:13-23` `existing = query token → update else add`.
- Token refresh `onTokenRefresh` `POST /device-token` again.
- `GET /notifications/device-token` not needed, `device_tokens` `user_id` `token` `platform` `created_at` `updated_at`.

## Notification Events (10 types)

| Event | Trigger | Backend | FCM | DB | Flutter Tap |
|---|---|---|---|---|---|
| `booking confirmed` `slot_confirmed` | `POST /bookings 201` `send_slot_confirmed` | `create_notification(user_id, Booking Confirmed, Token P.., slot_confirmed, {booking_id})` + `FCM send` if creds else `[FCM-MOCK]` | `notifications` `title Slot Confirmed` `is_read false` | `notification_router slot_confirmed → /home` |
| `booking rescheduled` | `POST /bookings/{id}/reschedule 200` | `create_notification(Booking Rescheduled, rescheduled to 10:30, slot_confirmed, {booking_id})` | `notifications` | `/home` |
| `booking cancelled` | `POST /bookings/{id}/cancel 200` | `create_notification(Booking Cancelled, Token P.. cancelled. Slot freed., booking_cancelled, {booking_id})` to `bk_farmer.user_id` | `notifications` | `/history` |
| `reminder` | Not cron (future `apscheduler`), Flutter `Reminder ON (-30m)` snackbar `Reminder set for slot time -30 min` `day_planner:74` — **FCM reminder** via `turn_approaching` threshold already | `create_notification` if implemented | `notifications` | `/planner` |
| `queue movement` | `POST /queue/dev/advance` `WAITING→CALLED` | `create_notification(Token Called, Token P.. is next, token_called)` + `audit token_called` | `notifications` | `/queue` |
| `turn approaching` | `GET /queue/{bid}` `0<ahead<=2` `WAITING` once per booking `data.like booking_id` check | `create_notification(Your turn is approaching, Token P.. — 2 farmers ahead, turn_approaching)` `db.commit` | `notifications` `type turn_approaching` | `/queue` |
| `token called` | `POST /queue/{bid}/transition {to_status: CALLED}` | `create_notification(Token Called, ... token_called)` + `log_token_called` | `notifications` | `/queue` |
| `procurement update` | `POST /procurements/{bid}/advance {to_stage}` | `create_notification(Procurement Updated, Stage changed to X, procurement_stage_updated, {booking_id, stage})` + `log_procurement_completed` | `notifications` | `/procurement` |
| `procurement completed` | `POST /procurements/{bid}/advance COMPLETED` | same `procurement_stage_updated` `COMPLETED` | `notifications` | `/procurement` |
| `payment update` | `POST /payments/{bid}/status {status: COMPLETED}` | `create_notification(Payment Status Updated, Payment status: COMPLETED, payment_status_updated, {booking_id, status})` + `audit payment_updated` | `notifications` | `/payment` |
| `centre closure` | `PATCH /centres/{id} {status: Closed/Emergency, closure_reason}` | `create_notification(Centre Closed/Emergency, {name} is closed. Heavy rain..., centre_closure, {centre_id, booking_id})` to 5 affected `CONFIRMED` `today_bk` | `notifications` | `/centres` |

## Flutter Handling

- `fcm_service.dart` `init` `requestPermission` `getToken` `onMessage` `showLocalNotification` `onMessageOpenedApp` `getInitialMessage` → `notification_router.handleTap(context, data)` `type` `booking_id`.
- `notification_router.dart` `handleTap` `switch type` `turn_approaching/token_called/queue → /queue?bookingId`, `procurement_stage_updated → /procurement`, `payment_status_updated → /payment`, `slot_confirmed → /home`, else `/notifications`.
- `notifications_screen.dart` `FutureProvider _notifsPaginatedProvider` `GET /notifications?limit=20&offset=0` `limit 20` `Load more` + `Showing 20 most recent`, `AppCard` `Icon slot_confirmed` `title/body/timeAgo` `is_read` dot `8` `POST /notifications/{id}/read` `is_read true`.
- `adb reverse` device `127.0.0.1:8000` verified `POST /auth/send-otp 200` from `V2338`.

## Persistence

- `GET /notifications?limit=50&offset=0` `limit 1-100` `order desc created_at` `limit/offset` `notifications` table `is_read` `created_at` `data JSON`.
- `POST /notifications/{id}/read` `is_read true` `db.commit` `404` if not owner.
- `FCM` unavailable dev → `notification` record still `200` `is_read false` persisted, `[FCM-MOCK]` log, not `fake "notification sent successfully"` without DB.

## Security

- `Authorization: Bearer` required for `device-token` `GET /notifications` `POST /{id}/read`, `user_id` from `JWT` not client, `notification.user_id == user.id` else `404`, not `403` to avoid enumeration.

