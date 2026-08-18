# Promt Build a Mobile Application with Flutter + Dart

Use the attached UI reference images as the **Visual Design Source of Truth**.

![faktee.png](Promt%20Build%20a%20Mobile%20Application%20with%20Flutter%20+%20Da/c4972de9-4255-4451-b2ac-23432289afc6.png)

## Goal

Build an app for:

- Scheduling meetups with friends
- Inviting friends to join an event
- Sharing member locations during a meetup
- Enabling Live Location 1 hour before the meetup start time
- Viewing where members currently are
- Checking who has arrived
- Checking in / checking that members have headed home
- Managing Friends
- Viewing Profile / Badges / participation statistics

**Do NOT build only static mockup screens.** Build a real Flutter application with navigation, state management, interaction, and a mock repository layer that can later be connected to Firebase.

---

# 1. UI DESIGN DIRECTION

Use the attached reference images as the primary source of truth.

**Visual Style:**

- Premium dark mobile application
- Minimal
- Modern
- Map-centric
- Dark gray / black background
- White typography
- Muted gray secondary text
- Red / dark red as the primary accent color
- White pill-shaped buttons
- Rounded cards
- Thin dividers
- Compact spacing
- Subtle shadows
- Small avatar circles
- Minimal icons
- Bottom navigation, iOS / modern mobile app style

Do not redesign the UI in a way that deviates significantly from the reference.

You must preserve:

- Card sizes
- Border radius
- Spacing
- Typography hierarchy
- Map proportions
- Bottom navigation
- Avatar style
- Button style
- Colors
- Visual density

### Design System

**Identity**
Dark-mode mobile app. Use **DM Sans** (variable font, opsz 14) for every text node. No light mode — every background layer is near-black at varying levels of darkness.

**Colors**

Background:

| Token | Hex | Usage |
| --- | --- | --- |
| bgBase | #141414 | app shell, nav bar, flat cards |
| bgElevated | #1f1f1f | raised / active cards |
| bgSurface | #242424 | progress track, input fill |
| bgAvatar | #1e2939 | avatar circle fill |

Border:

| Token | Hex | Usage |
| --- | --- | --- |
| borderSubtle | #2a2a2a | default card & nav border (0.6px) |
| borderMuted | #333333 | slightly lighter card border |

Text:

| Token | Hex | Usage |
| --- | --- | --- |
| textPrimary | #ffffff | headings, active labels |
| textBody | #e5e7eb | body content |
| textSecondary | #d1d5dc | status bar time, de-emphasized text |
| textMuted | #99a1af | metadata, captions, inactive nav |

Accent:

| Token | Hex | Usage |
| --- | --- | --- |
| accentDanger | #7c1d1d | progress bar fill, arrival indicator |

**Typography**

Font: DM Sans (Google variable font). Always set `fontVariationSettings: "opsz" 14` on every text element.

| Token | Size | Weight | Leading | Notes |
| --- | --- | --- | --- | --- |
| displayLg | 18px | 700 Bold | 28px | Screen titles |
| titleMd | 14px | 600 SemiBold | 20px | Card titles |
| bodyMd | 14px | 500 Medium | 20px | List item names |
| captionMd | 12px | 400 Regular | 16px | Meta / date / count |
| labelSm | 10px | 600 SemiBold | 15px | Section headers — ALL CAPS, 0.25px tracking |
| microSm | 10px | 500 Medium | 15px | Nav labels |
| tinySm | 8px | 500 Medium | 12px | Avatar initials |
| statusBar | 12px | 600 SemiBold | 16px | iOS status bar time |

**Spacing**
xs 4px · sm 8px · md 12px · lg 16px · xl 20px · xxl 24px

**Radius**
sm 8px · md 12px · lg 16px (cards, rows) · full 9999px (avatars, pills, progress bar)

**Shadow**
card: `0px 1px 1.5px rgba(0,0,0,0.1), 0px 1px 1px rgba(0,0,0,0.1)`

---

# 2. APP NAVIGATION

Bottom navigation has 5 tabs:

1. Home
2. Groups
3. Notifications
4. Profile

Navigation tree:

```
Home
 ├── Meetup Detail
 ├── Live Meetup
 ├── Create Meetup
 │    ├── Select Location
 │    ├── Meetup Details
 │    └── Invite Friends
 │
Groups
 ├── Upcoming
 ├── Upcoming/Waiting
 └── Past

Notifications
 ├── Meetup Invitation
 └── Meetup Updates

Profile
 ├── Statistics
 ├── Badges
 └── Settings
```

---

# 3. HOME SCREEN

Build the Home screen according to the reference.

**Header**

Top of screen — search bar:

```
🔍 Find a location...
```

Dark, rounded search field.

**Map**

The map is the main area of the screen.

Use Google Maps or Mapbox.

Build a `MapWidget` abstraction so the provider can be swapped later.

Show meetup markers on the map.

**Create Meetup Button**

Always shown above the Active Groups card. Floating pill button:

```
+ Create Meetup
```

Tapping it navigates to Create Meetup.

**Active Groups Card**

Bottom sheet / card:

```
Active Groups                         1 active

Dinner @ Nobu Downtown
Tonight · 10:30 PM · 5 people

[AC] [MP] [JL] +2

━━━━━━━━━━━━━━━━━━
2 of 5 arrived
```

The card must overlay the bottom of the map.

---

# 4. CREATE MEETUP FLOW

3 steps, per the reference.

Progress indicator:

```
Create Meetup · Step 1 of 3
```

---

## Step 1 — Select Location

Header:

```
Select Location
Create Meetup · Step 1 of 3
```

Search:

```
Search for a place
```

Map

When a location is selected:

```
Nobu Downtown
```

Button:

```
Confirm Location
```

---

# 5. STEP 2 — MEETUP DETAILS

Header:

```
Meetup Details
Create Meetup · Step 2 of 3
```

Form:

Name:

```
Dinner meetup, splitting the bill for dessert
```

Date Picker — dark calendar

Time Picker, example:

```
10 : 30 PM
```

Location card:

```
Nobu Downtown
195 Broadway, New York, NY
```

Button:

```
Confirm Details
```

---

# 6. STEP 3 — INVITE FRIENDS

Header:

```
Invite Friends
Create Meetup · Step 3 of 3
```

Search:

```
Search Instagram friends...
```

List:

```
Alex Chen       @alexc          ○
Maya Patel      @mayap          ○
Jordan Lee      @jlee           ○
Sam Rivera      @samr           ○
Chris Wong      @chriswong     ○
Priya Sharma    @priya_s        ○
Marcus Webb     @marcusw        ○
```

Multi-select is supported.

When friends are selected:

```
4 selected
```

Bottom button:

```
Send 4 Invitations
```

After the meetup is created, show the **MEETUP DETAIL SCREEN**.

---

# 7. MEETUP DETAIL SCREEN

There are 2 variants: if the meetup is within the 1-hour window before start time, show the **LOCATION SHARING RULE** screen instead. If the meetup is in the past or further in the future, show the **MEETUP DETAIL SCREEN** with **MEMBER STATUS**.

Header:

```
‹  Dinner meetup, splitting the bill for dessert          Share
```

Info block:

```
Location

Kanori Embassy

Date
Friday, August 14, 2026

Time
19:00
```

Map — shows a marker at the meetup location.

---

# 8. MEMBER STATUS

Show members:

```
Members

[AC] Alex Chen
     @alexc                         Accepted

[MP] Maya Patel
     @mayap                         Accepted

[JL] Jordan Lee
     @jlee                          Pending

[SR] Sam Rivera
     @samr                          Pending
```

Status badges:

- Accepted
- Pending
- Declined

---

# 9. LOCATION SHARING RULE

This is a **core feature** of the app. It replaces the Meetup Detail screen when active.

If the meetup:

```
Start = 19:00
```

Location Sharing opens at:

```
18:00
```

i.e.:

```
startTime - 1 hour
```

**Before 18:00**

Member locations must NOT be shown.

The map only shows the meetup location.

Message:

```
Member locations will be shown 1 hour before the meetup starts
```

Or a countdown:

```
Location sharing starts in 42 minutes
```

---

# 10. LIVE MEETUP SCREEN

When `startTime - 1 hour` is reached, switch to the Live Meetup screen.

Example (per reference):

Top bar:

```
‹  Nobu Downtown

● Live · 2 arrived · 2 on the way

                               10:30 PM
```

Full-screen map.

Members shown with custom circular markers, each displaying an avatar/initial.

If it's the current user's position:

- Marker has a red ring
- Shows a timestamp

Example:

```
Maya
8 min
```

---

# 11. LIVE LOCATION MEMBER CARD

Below the live map, show a draggable bottom sheet.

It shows the current user's own live activity status:

- **Haven't left home yet** → shows "You should be done by 10:50" and a button **[ I've left ]**
- **Left home** → "On the way"
- **A friend has arrived but you haven't** → "Your friend has arrived, you should hurry"
- **Arrived** → "Want to help greet your friends? [ I've arrived ]"
- **Everyone has arrived** → shows a button **[ Go Home / Leave Meetup Flow ]**

Example:

```
You should be done by 10:50

[ I've Arrived ]

Members                              2 of 5 arrived
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sam Rivera
Pending                                      8 min  [ ฝากที ]

Maya Patel
On the way                                   10 min   [ ฝากที ]

Jordan Lee
On the way                                    8 min  [ ฝากที ]
```

Use a draggable bottom sheet (expand/collapse).
 ฝากที  button (playful poke)
For any member row where the status is not "Arrived" (i.e. `Pending` or `On the way`), show a small button on the right side of that member's row:

```
[  ฝากที  ]
```

- Once a member has arrived, hide/remove the Nudge button from their row — it should only appear for members who haven't arrived yet.
- Tapping it sends {}
- Add a short cooldown after tapping (e.g. disable the button for ~30–60 seconds, or show "Nudged" briefly) so a member can't be spammed with nudges.
- Tapping Nudge should NOT affect that member's actual arrival/on-the-way status — it's purely a social/fun interaction layered on top of the real status data.

Use a draggable bottom sheet (expand/collapse).

---

# 12. ARRIVAL SYSTEM

Calculate distance from the meetup location.

Example rule:

```
distance <= 100 meters
```

→ considered:

```
Arrived
```

If still far:

```
On the way
```

Example:

```
Sam Rivera
Pending

Maya Patel
8 min · On the way

Jordan Lee
5 min · On the way
```

When a member arrives:

```
Maya Patel
Arrived
```

And update:

```
3 of 5 arrived
```

---

# 13. BUTTON — CONFIRM ARRIVAL

In Live Meetup, the user can tap:

```
I've Arrived
```

to self-confirm arrival.

The backend must also verify GPS distance — **do not trust the client alone**.

On success:

```
✓ You have arrived
```

Button becomes disabled/gray.

---

# 14. HOME / LEAVE MEETUP FLOW

Reference includes a prompt screen:

```
Heading home?

Choose a new destination
```

Build a screen:

## Going Home

Header:

```
Heading home?
```

Subtitle:

```
Let your friends know you're on your way home
```

Option:

```
Choose a new destination                  >
```

Saved locations:

```
Home (Default)                    ✓
Ratchada 7, Ratchada, Bangkok

Condo
Ratchada 7, Ratchada, Bangkok
```

Button:

```
Confirm Going Home
```

---

# 15. RETURN HOME / LEAVING STATE

When the user taps "Going Home":

Change status to:

```
Heading home
```

Stop sharing meetup location where appropriate per privacy rules.

Members can see only a status such as:

```
Riley
Heading home
```

There's no need to keep sharing location after the meetup participation has ended.

---

# 16. GROUPS SCREEN

Build the Groups screen per the reference.

Header:

```
Your Groups
```

Sections:

```
TONIGHT

Dinner @ Nobu Downtown
Tonight · 10:30 PM · 5 people
                               2 of 5 arrived

UPCOMING

Rooftop · Soho House
Aug 20 · 9:00 PM · 7 people

PAST

Nobu Dinner
Jul 28 · 5 people

Rooftop at Soho House
Jul 14 · 7 people

Picnic in Central Park
Jun 30 · 4 people

Gallery Opening — 47 Canal
Jun 12 · 6 people
```

Each item is a dark card with a chevron `>`. Tapping it navigates to Meetup Detail.

---

# 17. GROUP STATUS

A meetup can have status:

```
Upcoming
Live
Arrived
Completed
Cancelled
```

Use slightly different accent colors per status.

---

# 18. PROFILE SCREEN

Build the Profile screen per the reference.

Top section: large circular avatar.

```
Riley Kim
@rileyk
```

Rating:

```
★★★★★ 4.3 (21.5K)
```

```
16                    5
On time              Late
```

---

# 19. NOTIFICATIONS

Build the Notifications screen. Support:

- Meetup invitation
- Meetup accepted
- Meetup starting soon
- Location sharing started
- Friend arrived
- Meetup cancelled
- Someone is heading home

Example:

```
Maya invited you to Dinner @ Nobu Downtown

10 min ago
```

---

# 20. FINAL IMPLEMENTATION GOAL

The app must support this full end-to-end demo flow:

```
Open App
 ↓
Home
 ↓
Tap + Create Meetup
 ↓
Select location
 ↓
Enter name + date + time
 ↓
Select friends
 ↓
Send invitations
 ↓
Meetup Detail
 ↓
More than 1 hour before meetup:
Friend locations not visible
 ↓
Countdown
 ↓
1 hour remaining
 ↓
Live Location opens
 ↓
See members on the map
 ↓
Members travel to the location
 ↓
Show "On the way"
 ↓
Arrives within 100m
 ↓
Arrived
 ↓
Tap "I've Arrived"
 ↓
Show "3 of 5 arrived"
 ↓
Meetup ends
 ↓
Location sharing stops
 ↓
Choose "Heading home?"
 ↓
Choose Home / Condo
 ↓
Confirm going home
 ↓
Return to Home
```

**Most important:** every screen's UI must feel like a continuous, cohesive application — not a series of disconnected mockups. Use the latest reference image as the visual source of truth for spacing, colors, typography, card layout, map layout, bottom navigation, and interaction patterns.

Start by creating the Flutter project + routing + theme + mock repository + all screens per the reference. Then wire up the business logic.