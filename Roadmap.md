# Gifted Roadmap

Where the CloudKit rebuild stands and what comes next. For how the app is built today, see the [README](README.md).

## Status

| Phase | What | State |
|---|---|---|
| 0 | Remove Amplify, move to your own team and bundle IDs, iOS 17+, XcodeGen | Done |
| 1 | Solo wishlist: local SwiftData store, iCloud sync with `CKSyncEngine`, add from link/photo, share extension | Done |
| 2 | Invite friends to see your wishlists (zone-wide `CKShare`); Friends tab | Built and unit tested, **not yet tested between two real iCloud accounts** |
| 3 | Gift circles: claim gifts and split costs, hidden from the recipient | Next |
| 4 | Notifications, occasions and polish | Planned |
| 5 | Release: TestFlight and App Store | Planned |

## Before phase 3: confirm phase 2 works

Claims in phase 3 point at items in a friend's shared zone, so sharing has to work before anything is built on top of it.

- [ ] Run the two-account test on real devices (both Debug builds, so both use the Development environment):
  1. On device A: My Lists → invite button → enter a name → Invite Friends → Copy Link.
  2. Open the link on device B. Gifted should switch to Friends and show A's lists.
  3. Add, edit and delete a gift on A; each change should appear on B within a few seconds.
  4. Change a photo on A; B should get the new image.
  5. Remove the friend on B, and separately Stop Sharing on A; A's lists should disappear from B.
  6. Sign out of iCloud on B; friends' data should be wiped.
- [ ] Open the invite link with Gifted closed (cold launch) as well as already running.
- [ ] Open your own invite link and check you get the "That's your own invite link" message.
- [ ] Check what the invite looks like in Messages; the thumbnail is currently missing (see Known issues).

## Phase 3: Gift circles

**Goal:** friends of a recipient work out who's buying what, and split expensive gifts, without the recipient ever seeing it. This was the feature the original app never finished.

### Core rule: the recipient can never read coordination data

Anyone in a CloudKit share can read everything in it, and the owner of a zone can always read it. So claims can't live in the recipient's zone next to their wishlist. They live in a separate **circle zone** that one gifter owns and shares only with the other gifters.

```
Alice's private DB              Bob's private DB (Bob organises)
└─ Wishlists zone ──share──►    └─ Circle-<id> zone ──share──► Carol, Dan
   (Bob, Carol, Dan read)          ├─ Circle   (recipient = Alice's zone owner, occasion, date)
                                   ├─ Claim    (one per claimed item)
                                   └─ Contribution (one per person per split item)
```

Alice is never invited to the circle, so there's nothing for her app to fetch, even by accident.

### Data model (draft)

| Record | Key fields | Record name |
|---|---|---|
| `Circle` | recipient owner name, recipient display name, occasion title, occasion date, optional budget | `circle` (one per zone) |
| `Claim` | item key (recipient owner + item record name), claimer, status (`reserved` / `bought`), created at | `claim-<item record name>` |
| `Contribution` | item key, contributor, amount, currency, paid (bool) | `contrib-<item>-<contributor>` |

Fixed record names do the conflict handling:
- **One claim per item:** if two people claim the same item at the same moment, the second save fails with `serverRecordChanged`, and that app shows "Carol already claimed this".
- **One contribution per person per item:** each person only ever writes their own record, so contributors never conflict with each other.

### Sync

- Circles you **organise** live in your private database. That needs either a second zone type in the private `CKSyncEngine`, or a separate engine filtered to `Circle-*` zones.
- Circles you've **joined** arrive through the shared database alongside friends' wishlists. `FriendsSync` needs to tell them apart by zone name (`Wishlists` = a friend's lists, `Circle-*` = a circle). The shared-database engine also has to start **sending** changes, because members write their own claims and contributions into the organiser's zone. It's read-only today.
- Unlike wishlists, circle members need write access, so circle shares use read-write permission.
- Local models: `Circle`, `Claim`, `Contribution`, keyed by `<zone owner>/<record name>` as the friend models are.

### UI

- On a friend's gift: **Claim**, **Split with others**, or **Join split**, plus the current status (e.g. "Bob is getting this" or "$80 of $129.95 pledged").
- Status badges on friend gift cards: claimed, or split progress.
- **Start a circle** from a friend's profile: pick the occasion, then invite other gifters with the usual sharing screen.
- Circle screen: members, the occasion countdown, claimed and split items, who owes what, and "Mark as paid" toggles.
- No payments inside the app; it only records who has paid whom.

### Open questions

- **Several circles for one recipient.** Two groups could each start a circle for Alice's birthday and not see each other's claims. Options: accept it and show "anyone else could be buying this too" guidance; prompt to "join an existing circle" when someone shares one; or keep one circle per recipient per occasion by convention.
- **Finding other gifters.** Nobody can see a recipient's whole friend list, so the organiser has to know who to invite. Is an invite link the organiser posts in a group chat enough?
- **Spoilers through the wishlist.** If the recipient deletes an item someone has already bought, the claim is left pointing at nothing. Show it as "no longer on their list" instead of deleting it. Should a "bought" status also nudge the recipient's app in some way? Probably not, for privacy.
- **Over-funding.** Contributions could add up to more than the price. Warn about it, but don't block it.
- **After the occasion.** Archive the circle after its date? Who can delete it?

### Tests

- A circle store (like `FriendStore`) covering claim and contribution upserts, item keys across owners, and orphaned claims.
- Two people claiming the same item: the second gets a "claimed by" message instead of an error.
- The recipient's app never ends up with circle data, even if they're also a member of another circle.

## Phase 4: Notifications, occasions and polish

**Notifications.** `CKSyncEngine` already wakes the app with silent pushes; turn interesting changes into local notifications:
- A friend added gifts to their list.
- Someone joined your circle, claimed something, or a split is fully pledged.
- An occasion is coming up: "Alice's birthday is in 2 weeks; nothing's claimed yet".
- Never notify a recipient about anything to do with their own gifts.

**Occasions.** Add an optional date (birthday, Christmas) to each wishlist, show a countdown, and remind gifters before it.

**Wishlist features**
- Private lists that aren't shared. With zone-wide sharing this means moving them to a separate, unshared zone.
- "Most wanted" priority, quantity, and structured size/colour.
- Mark as received, and archive after the occasion.
- Refresh the price and photo from the item's link.

**Explore and search.** Bring back the original Explore tab: search across your own and friends' gifts.

**System integration**
- A home screen widget for the next occasion or recently added gifts.
- An App Intent / Shortcut: "Add to Gifted".
- iPad support: the app is iPhone-only for 1.0. Adding iPad means a layout pass and 13" iPad screenshots.
- Dynamic Type, VoiceOver and dark-mode audit.

**Onboarding.** A first-run screen that explains the share extension and inviting friends.

## Phase 5: Release

- [ ] Deploy the CloudKit schema to Production in the CloudKit Console (record types plus any indexes). TestFlight and App Store builds use Production, and two people can only share if both builds use the same environment.
- [x] App icon meets App Store rules (1024×1024, no transparency). Consider refreshing the design.
- [x] Privacy manifest (`Gifted/PrivacyInfo.xcprivacy`) declaring UserDefaults use.
- [x] `ITSAppUsesNonExemptEncryption = NO`, so there are no export compliance questions on upload.
- [x] iPhone only, version 1.0.
- [ ] Settings: add **Delete All My Data**, which deletes the iCloud zones, leaves all shares and wipes local data.
- [ ] Privacy policy URL, and the App Privacy answers. Data lives in the user's own iCloud; the app has no server and no analytics.
- [ ] Screenshots, App Store description, TestFlight beta with a few friend groups.
- [ ] Turn `-seedSampleData` off in release, and keep the sample-data code behind `#if DEBUG`.

## Known issues and tech debt

- **No thumbnail in invites:** `UIImage(named: "AppIcon")` returns nil, so Messages shows no picture for invites. Add a dedicated image asset for it.
- **Price sort with mixed currencies:** sorting compares raw numbers across currencies, and the list total is hidden when currencies differ.
- **Coarse conflict policy:** the last device to save a record wins, and edits made at the same time on two devices aren't merged field by field.
- **`SyncManager` event handling has no tests:** move its apply and conflict logic into a testable store, as `FriendStore` does.
- **Share extension items wait for the app:** they're only imported and uploaded when Gifted next opens. A background task could pick them up sooner.
- **Sample friend side effect:** in Debug builds, removing the `-seedSampleData` friend queues a zone deletion for a share that doesn't exist. It's harmless, but noisy in the logs.
- **No UI tests:** add a small XCUITest smoke suite (add gift, edit, share extension import).
