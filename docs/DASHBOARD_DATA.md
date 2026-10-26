# Street Signal: data for the .NET dashboard

Updated 26 October 2026. Firebase project: `street-signal-app-8f363`.

This is everything the mobile app writes to Firestore, what the dashboard must write back, and which chart each field powers. The .NET server reads with a service account (`Google.Cloud.Firestore`), so it sees every document and **bypasses the Firestore rules**: always filter by the signed-in official's `areaIds`, and show aggregates only for private data.

## Collections at a glance

| Collection | Written by | Who can read it | Dashboard use |
| --- | --- | --- | --- |
| `reports/{id}` | App | Any signed-in user | Main source: live problems, charts, heatmap |
| `posts/{id}` | App | Any signed-in user | Community page: food, energy, water, transport, prepare |
| `households/{uid}` | App | Owner only | Aggregates: homes signed up, people covered |
| `households/{uid}/predictions/{id}` | App | Owner only | Forecast accuracy, warnings acted on |
| `households/{uid}/topups/{id}`, `/readings/{id}` | App | Owner only | Aggregate electricity spend |
| `households/{uid}/needs/{id}` | App | Owner only | Counts of homes needing help in an emergency |
| `users/{uid}` | App | Owner only | Role and consent |
| `areas/{areaId}` | App | Any signed-in user | Area picker |
| `alerts/{id}` | **Dashboard** | Any signed-in user | Send alert page; shown on residents' Home |
| `incidents/{id}` | **Dashboard** | Any signed-in user | Grouped reports, confirm / resolve |

All dates are Firestore `Timestamp`s (UTC). Money is in **cents** (int). `day`, `weekday` and `hour` use the phone's local time (SAST).

**Pilot data:** demo records have `pilot: true` and `source: "pilot"`. Label them on the dashboard ("pilot data"), or filter them out with `WhereEqualTo("pilot", false)`. Pilot reports and posts are written with the demo user's `uid` but a simulated `householdId` (`hh-001` to `hh-046`), so **count households with `householdId`, not `uid`**.

## `reports/{id}`: one resident report

| Field | Type | Example | Used for |
| --- | --- | --- | --- |
| `uid` | string | Firebase Auth uid | who wrote it |
| `householdId` | string | uid, or `hh-012` for pilot | **distinct households reporting** |
| `areaId`, `areaName`, `ward` | string | `soweto`, `Soweto`, `Ward 12` | area filter, labels |
| `people` | int | `4` | **people affected** (sum per incident) |
| `service` | string | `water` \| `electricity` | **pie: reports by service** |
| `status` | string | `off` \| `low_pressure` \| `dirty` \| `back_on` | **pie: problem type** |
| `note` | string | `Burst main on the main road` | incident detail (may be empty) |
| `startedAt` | timestamp | | timeline, live list |
| `restoredAt` | timestamp \| null | | open vs resolved |
| `durationMinutes` | int \| null | `245` | **typical outage length** |
| `day` | string | `2026-10-21` | **outages per day / week** |
| `weekday` | int 1–7 | `2` = Tuesday | **heatmap: weekday × hour** |
| `hour` | int 0–23 | `18` | heatmap, peak hours |
| `source` | string | `app` \| `pilot` | data quality |
| `pilot`, `pilotHousehold` | bool, string | | pilot data only |
| `createdAt` | server timestamp | | ingestion time |

- **Open problem** = `restoredAt == null` and `status != "back_on"`.
- A `back_on` report is written with `restoredAt = startedAt`; the app also sets `restoredAt` and `durationMinutes` on that resident's open reports for the same service.
- **Incident grouping** (for the Live reports page): same `areaId` + `service` + `status`, starting within 3 hours of each other.

## `posts/{id}`: community posts

| Field | Type | Example | Used for |
| --- | --- | --- | --- |
| `uid`, `householdId` | string | | who posted; count households with `householdId` |
| `displayName` | string | `Lerato` | first name only |
| `areaId`, `areaName`, `ward` | string | `soweto` | area filter |
| `sector` | string | `food` \| `energy` \| `water` \| `transport` \| `prepare` | **pie: community activity by sector** |
| `topic` | string | see table below | what kind of post |
| `kind` | string | `place` \| `offer` \| `request` \| `group` \| `check` | how people respond |
| `title`, `details` | string | `Maize meal 50 kg, split 5 ways` | list and detail view |
| `place` | string | `Behind the clinic` | rough location, never an address |
| `quality` | string \| null | `clear` \| `cloudy` \| `smell` \| `unsafe` | **water-quality table** (`topic = water_quality`) |
| `target` | int \| null | `5` | group buys: households needed |
| `members` | array of uid | | responses; `members.length` vs `target` = **group progress** |
| `open` | bool | | `false` once the poster closes it |
| `expiresAt` | timestamp \| null | | active = `open` and not expired |
| `contact` | string | WhatsApp number | only if the poster chose to share it; **don't show on public screens** |
| `createdAt`, `day` | timestamp, string | | timeline |
| `source`, `pilot`, `pilotHousehold` | | | data quality |
| `serverCreatedAt` | server timestamp | | ingestion time |

### Post topics

| `sector` | `topic` | Meaning | `kind` |
| --- | --- | --- | --- |
| food | `food_place` | Garden or food pantry | place |
| food | `food_group` | Bulk-buy group | group |
| food | `food_surplus` | Surplus food | offer |
| energy | `energy_charging` | Charging spot | place |
| energy | `energy_group` | Buy solar or gas together | group |
| water | `water_quality` | Water quality check | check |
| water | `water_point` | Working water point or tanker | place |
| water | `water_share` | Spare stored water | offer |
| transport | `ride_offer` | Offer a lift | offer |
| transport | `ride_request` | Need a lift | request |
| transport | `lend_item` | Lend something | offer |
| transport | `access_issue` | Road or access problem | check |
| prepare | `prepare_offer` | Can help in an emergency | offer |

## Household data (private: aggregates only)

**`households/{uid}`:** `ownerUid`, `displayName`, `areaId`, `areaName`, `ward`, `people`, `electricity.billing` (`prepaid` / `postpaid`), `water.storageLitres`, `budgets.electricityCents`, `consent.data`, `createdAt`, `updatedAt`.

Every sub-collection document below is stamped with `areaId` and `householdId`, so you can query across households with `CollectionGroup("…").WhereEqualTo("areaId", areaId)`.

| Sub-collection | Fields | Used for |
| --- | --- | --- |
| `predictions` | `type` (`water_outage`, `power_outage`, `elec_runout`, `budget_overspend`), `service`, `title`, `message`, `action`, `probability`, `forDate`, `toDate`, `issuedAt`, `feedback` (`yes` / `partly` / `no` / null), `acted` | **forecast accuracy**, **hours of warning** (`forDate − issuedAt`), **% acted on** |
| `topups` | `date`, `amountCents`, `units` (kWh) | electricity spend per area |
| `readings` | `kind` (`elec_units`), `value` (kWh left), `at` | |
| `needs` | `kind` (`power_equipment`, `mobility`, `water`, `young_or_old`, `other`), `note`, `createdAt` | **homes needing help in an emergency**, counts per kind only |

**Never list individual households or their needs.** Show totals, e.g. "7 homes need power for equipment in Soweto".

**`users/{uid}`:** `displayName`, `householdId`, `role` (always `resident` from the app; officials get roles via custom claims), `consent` (`data`, `acceptedAt`).

**`areas/{areaId}`:** `name`, `ward`, `updatedAt`. `areaId` is the area name in lowercase with non-letters replaced by `-` (`Soweto Zone 6` → `soweto-zone-6`). Officials' `areaIds` must use the same IDs.

## Written by the dashboard

### `alerts/{id}`: shown live on residents' Home screen

The app shows the two newest alerts whose `areaIds` contains the resident's `areaId`.

| Field | Type | Example |
| --- | --- | --- |
| `areaIds` | array of string | `["soweto"]` |
| `service` | string | `water` \| `electricity` (sets the icon) |
| `title` | string | `Water off Thursday 09:00 to 15:00` |
| `body` | map | `{ "en": "Store water on Wednesday night." }` (a plain string also works) |
| `source` | string | `official` (highlighted) \| `community` |
| `sentAt` | timestamp | server time, used for ordering |

### `incidents/{id}`: grouped reports

`areaId`, `service`, `status` (`suspected` / `confirmed` / `resolved`), `reportCount`, `peopleAffected`, `firstReportAt`, `resolvedAt`, `confirmedBy`. The app doesn't read incidents yet.

## Dashboard pages and widgets

| Page | Widget | Source | How to compute |
| --- | --- | --- | --- |
| **Overview** | Open problems now | reports | open, last 12 h, count by `service` |
| | Households reporting | reports | distinct `householdId`, last 8 weeks |
| | People affected this week | reports | sum `people` per incident |
| | Forecast accuracy | predictions | (yes + 0.5 × partly) ÷ answered |
| | Reports by service (pie) | reports | group by `service` |
| | Outages per week (bar) | reports | group into incidents, then by ISO week of `day` |
| **Live reports** | Incident list | reports / incidents | newest first, open first; Confirm, Resolve |
| **Send alert** | Form | alerts | writes the format above |
| **Patterns** | When outages happen (heatmap) | reports | count by (`weekday`, `hour`) |
| | Typical outage length | reports | median `durationMinutes` by service |
| | Problem types (pie) | reports | group by `status` |
| **Community** | Activity by sector (pie) | posts | active posts grouped by `sector` |
| | Group buys | posts | `kind == group`: `members.length` / `target` |
| | Water quality | posts | `topic == water_quality`, newest first, flag anything not `clear` |
| | Access problems | posts | `topic == access_issue`, for roads and maintenance |
| | Emergency readiness | needs + posts | needs counted by `kind`; helpers = `topic == prepare_offer` |
| | Warnings acted on | predictions | `acted == true` ÷ issued |

## Shared values (put these in `Wire.cs`)

Stored exactly as written. Never use C# enum numbers. The source of truth is the app's `lib/core/enums.dart` and `lib/models/community.dart`.

```
service:        water | electricity
reportStatus:   off | low_pressure | dirty | back_on
incidentStatus: suspected | confirmed | resolved
predictionType: water_outage | power_outage | elec_runout | budget_overspend
feedback:       yes | partly | no
readingKind:    elec_units
alertSource:    official | predicted | community
billing:        prepaid | postpaid
source:         app | pilot
sector:         food | energy | water | transport | prepare
postKind:       place | offer | request | group | check
waterQuality:   clear | cloudy | smell | unsafe
needKind:       power_equipment | mobility | water | young_or_old | other
role:           resident | leader | official | partner | admin
```

## C# examples

### Models

```csharp
[FirestoreData]
public class ServiceReport
{
    [FirestoreDocumentId] public string Id { get; set; }
    [FirestoreProperty("householdId")] public string HouseholdId { get; set; }
    [FirestoreProperty("areaId")] public string AreaId { get; set; }
    [FirestoreProperty("people")] public int People { get; set; }
    [FirestoreProperty("service")] public string Service { get; set; }
    [FirestoreProperty("status")] public string Status { get; set; }
    [FirestoreProperty("startedAt")] public Timestamp StartedAt { get; set; }
    [FirestoreProperty("restoredAt")] public Timestamp? RestoredAt { get; set; }
    [FirestoreProperty("durationMinutes")] public int? DurationMinutes { get; set; }
    [FirestoreProperty("weekday")] public int Weekday { get; set; }
    [FirestoreProperty("hour")] public int Hour { get; set; }
    [FirestoreProperty("pilot")] public bool Pilot { get; set; }
}

[FirestoreData]
public class CommunityPost
{
    [FirestoreDocumentId] public string Id { get; set; }
    [FirestoreProperty("areaId")] public string AreaId { get; set; }
    [FirestoreProperty("sector")] public string Sector { get; set; }
    [FirestoreProperty("topic")] public string Topic { get; set; }
    [FirestoreProperty("title")] public string Title { get; set; }
    [FirestoreProperty("quality")] public string? Quality { get; set; }
    [FirestoreProperty("target")] public int? Target { get; set; }
    [FirestoreProperty("members")] public List<string> Members { get; set; } = new();
    [FirestoreProperty("open")] public bool Open { get; set; }
    [FirestoreProperty("expiresAt")] public Timestamp? ExpiresAt { get; set; }
    [FirestoreProperty("createdAt")] public Timestamp CreatedAt { get; set; }
}
```

### Reports by service (pie chart)

```csharp
var since = Timestamp.FromDateTime(DateTime.UtcNow.AddDays(-56));
var snap = await db.Collection("reports")
    .WhereEqualTo("areaId", areaId)
    .WhereGreaterThanOrEqualTo("startedAt", since)
    .GetSnapshotAsync();

var byService = snap.Documents
    .GroupBy(d => d.GetValue<string>("service"))
    .ToDictionary(g => g.Key, g => g.Count());
```

### Community activity by sector (pie chart)

```csharp
var posts = await db.Collection("posts").WhereEqualTo("areaId", areaId).GetSnapshotAsync();
var now = Timestamp.GetCurrentTimestamp();
var bySector = posts.Documents
    .Select(d => d.ConvertTo<CommunityPost>())
    .Where(p => p.Open && (p.ExpiresAt == null || p.ExpiresAt > now))
    .GroupBy(p => p.Sector)
    .ToDictionary(g => g.Key, g => g.Count());
```

### Emergency needs per kind

```csharp
var needs = await db.CollectionGroup("needs").WhereEqualTo("areaId", areaId).GetSnapshotAsync();
var byKind = needs.Documents
    .GroupBy(d => d.GetValue<string>("kind"))
    .ToDictionary(g => g.Key, g => g.Count());   // show counts only
```

### Send an alert

```csharp
await db.Collection("alerts").AddAsync(new Dictionary<string, object>
{
    ["areaIds"] = new[] { "soweto" },
    ["service"] = "water",
    ["title"] = "Water off Thursday 09:00 to 15:00",
    ["body"] = new Dictionary<string, object> { ["en"] = "Store water on Wednesday night." },
    ["source"] = "official",
    ["sentAt"] = FieldValue.ServerTimestamp,
});
```

## Indexes

- `reports`: `areaId` ascending + `startedAt` ascending (for the time-range query above).
- Collection-group queries on `needs` and `predictions` filtered by `areaId` need a single-field collection-group index on `areaId`.

Firestore logs a one-click link to create each index the first time a query needs it.
