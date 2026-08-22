# Tasker WebUI notification deduplication reference

This reference captures a working pattern for deduplicating notifications from two Android mail clients while retaining one preferred notification.

## Observed WebUI API shape

Useful read-only endpoints:

- `GET /ping`
- `GET /explore`
- `GET /actions`
- `GET /variables`
- `GET /category_specs`
- `GET /action_specs?category_code=<integer>`
- `GET /arg_specs`

Observed mutation endpoints:

- `POST /actions` — insert at index
- `PATCH /actions` — append
- `PUT /actions` — replace at index
- `GET /delete?index=<integer>` — delete
- `GET /move?from=<integer>&to=<integer>` — reorder
- `GET /label?index=<integer>&value=<string>` — label

Inspect `/explore` every time; it is the running version's contract.

Mutation bodies use a wrapper such as:

```json
{
  "action": "{\"code\":474,\"name\":\"Java Code\",\"args\":[...]}"
}
```

In other words, the outer body is JSON and `action` is a string containing another JSON object. The page's own JavaScript confirms this by collecting form strings and sending `JSON.stringify(jsonBody)`.

## Relevant discovered action metadata

- Alert category: `10`
- Code category: `35`
- Task category: `105`
- Tasker category: `110`
- Variables category: `120`
- Flash action: `548`
- Java Code action: `474`
- Tasker's `Notify Cancel`: `779` (for Tasker-created notifications; not the correct primitive for arbitrary app notifications)

Java Code arguments observed:

| ID | Name | Value type |
|---:|---|---|
| 0 | Code | string |
| 1 | Return | optional string |
| 2 | Structure Output (JSON, etc) | boolean |

## Mail package IDs

- Proton Mail: `ch.protonmail.android`
- Spark Mail: `com.readdle.spark`

Confirm package IDs against the installed apps or current Play Store records when reusing this pattern.

## Why active-notification scanning is robust

A Tasker Notification event may run first for either mail app. Keeping only a “last notification” variable introduces ordering and timeout problems. Instead, each event can:

1. Ask Tasker's notification listener for all active notifications.
2. Build lists for both packages.
3. Compare normalized title + text across the lists.
4. Cancel matching notifications from only the less-preferred app by notification key.

After cancellation, later runs do not rematch that notification because it is no longer active.

## BeanShell Java Code template

Tasker Java Code uses BeanShell-like Java and provides `context` and `tasker` helper variables.

```java
import android.app.Notification;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import java.util.ArrayList;
import java.util.Locale;

String field(Bundle extras, String key) {
    if (extras == null) return "";
    CharSequence value = extras.getCharSequence(key);
    return value == null ? "" : value.toString();
}

String norm(String value) {
    if (value == null) return "";
    return value
        .replaceAll("[\\u200B-\\u200D\\uFEFF]", "")
        .replaceAll("\\s+", " ")
        .trim()
        .toLowerCase(Locale.US);
}

NotificationListenerService listener = tasker.getNotificationListener();
if (listener == null) {
    tasker.showToast("Mail dedupe unavailable: enable Tasker's notification access");
    return null;
}

StatusBarNotification[] active = listener.getActiveNotifications();
ArrayList proton = new ArrayList();
ArrayList spark = new ArrayList();

for (int i = 0; i < active.length; i++) {
    StatusBarNotification item = active[i];
    Notification notification = item.getNotification();
    if (notification == null) continue;
    if ((notification.flags & Notification.FLAG_GROUP_SUMMARY) != 0) continue;

    if ("ch.protonmail.android".equals(item.getPackageName())) proton.add(item);
    if ("com.readdle.spark".equals(item.getPackageName())) spark.add(item);
}

int dismissed = 0;
for (int i = 0; i < proton.size(); i++) {
    StatusBarNotification p = (StatusBarNotification) proton.get(i);
    String pTitle = norm(field(p.getNotification().extras, Notification.EXTRA_TITLE));
    String pText = norm(field(p.getNotification().extras, Notification.EXTRA_TEXT));
    if (pTitle.length() == 0 || pText.length() == 0) continue;

    for (int j = 0; j < spark.size(); j++) {
        StatusBarNotification s = (StatusBarNotification) spark.get(j);
        String sTitle = norm(field(s.getNotification().extras, Notification.EXTRA_TITLE));
        String sText = norm(field(s.getNotification().extras, Notification.EXTRA_TEXT));
        if (pTitle.equals(sTitle) && pText.equals(sText)) {
            listener.cancelNotification(p.getKey());
            dismissed++;
            break;
        }
    }
}

if (dismissed > 0) {
    tasker.showToast("Duplicate mail: dismissed " + dismissed + " Proton notification" + (dismissed == 1 ? "" : "s"));
}
return null;
```

## Safe edit and verification sequence

1. Save `GET /actions` to a timestamped backup.
2. Append the Java Code action with `PATCH /actions` rather than immediately overwriting the old action.
3. Confirm the response and a fresh `GET /actions` contain:
   - exactly one candidate Java Code action,
   - action code `474`,
   - both package IDs,
   - `cancelNotification(...getKey())`,
   - the toast call.
4. Delete the previous debug action only after the candidate round-trips.
5. Save a post-change snapshot.
6. Trigger a uniquely titled self-email.
7. Confirm SMTP submission and mailbox delivery independently.
8. Confirm on the phone that Spark remains, Proton disappears, and the toast appears.

The configuration check and mailbox-delivery check are machine-verifiable. Notification-shade behavior still requires either device-side logs/inspection or user observation unless the running Tasker surface advertises a suitable execution/log endpoint.

## Tuning when the first test does not match

Do not immediately loosen matching to title-only. First collect, for both packages:

- `EXTRA_TITLE`
- `EXTRA_TEXT`
- `EXTRA_BIG_TEXT`
- `EXTRA_SUB_TEXT`
- package name
- notification key
- whether the entry is a group summary

Then choose the narrowest common signature. Common next options are normalized title + first line of text, or title + subject extracted from big text. Preserve the non-empty guards and package filter.
