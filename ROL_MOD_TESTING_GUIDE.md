# ROL_MOD Testing Guide

> **Historical document (early ROL_MOD).** These scenarios test the original
> demo-mode Family tab implementation, whose UI structure has since been replaced.
> For current state see `docs/07_CURRENT_STATE.md`.

## Prerequisites
- Build and run the app in Demo Flow mode
- Ensure `AppConfig.isDemoFlowEnabled` is `true`

## Test Scenarios

### 1. Initial Launch
**Expected:**
- App launches successfully
- User switcher visible at top showing "Rue Mawere" selected
- Tab bar visible at bottom with 4 tabs: My Runs, Family, Activity, Settings
- My Runs tab is selected by default

### 2. Family Tab Navigation
**Steps:**
1. Tap on "Family" tab
2. Observe the family list screen

**Expected:**
- Title: "Family"
- Demo hint: "Demo family — can be removed later"
- Grid showing 4 members:
  - Rue Mawere (Parent, Observer, Admin)
  - Tafadzwa Mawere (Parent, Driver, Admin)
  - TJ (Child, Observer, Passenger)
  - Tawana (Child, Observer, Passenger)
- Each card shows: avatar with initials, name, role badges, capability line

### 3. Member Profile - Parent (Rue)
**Steps:**
1. Tap on "Rue Mawere" card
2. Review profile details

**Expected:**
- Header: Large "RM" avatar, "Rue Mawere", "Parent"
- Roles section: Parent, Observer, Admin badges
- Permissions section:
  - ✓ Can create runs
  - ✓ Can track runs
  - ✓ Can manage family
  - ✓ Can cancel/reassign runs
- Contact section: +1-555-0101
- Run Context section: Assigned runs count, Visible runs count
- Demo Only section: "View as this user" button

### 4. Member Profile - Driver (Tafadzwa)
**Steps:**
1. Go back to Family list
2. Tap on "Tafadzwa Mawere" card
3. Review profile details

**Expected:**
- Header: Large "TM" avatar, "Tafadzwa Mawere", "Parent"
- Roles section: Parent, Driver, Admin badges
- Permissions section:
  - ✓ Can create runs
  - ✓ Can start/drive runs
  - ✓ Can track runs
  - ✓ Can manage family
  - ✓ Can cancel/reassign runs
- Contact section: +1-555-0102 with "Call Driver" button
- Run Context section: Assigned runs count, Visible runs count
- Demo Only section: "View as this user" button

### 5. Member Profile - Child (TJ)
**Steps:**
1. Go back to Family list
2. Tap on "TJ" card
3. Review profile details

**Expected:**
- Header: Large "TJ" avatar, "TJ", "Child"
- Roles section: Child, Observer, Passenger badges
- Permissions section:
  - ✓ Can create runs
  - ✓ Can track runs
- Contact section: "No contact information"
- Run Context section: Visible runs count
- Demo Only section: "View as this user" button

### 6. User Switching from Profile
**Steps:**
1. From TJ's profile, tap "View as this user"
2. Confirm in alert dialog
3. Observe changes

**Expected:**
- Alert: "Switch to TJ?"
- After confirming:
  - Profile sheet dismisses
  - User switcher at top updates to "TJ"
  - My Runs tab updates to show TJ's perspective
  - Console log: "🔄 Switched to user: TJ (role: Observer)"

### 7. User Switching from Top Switcher
**Steps:**
1. Tap on user switcher at top
2. Select "Tafadzwa Mawere"
3. Navigate to My Runs tab

**Expected:**
- User switcher updates to "Tafadzwa Mawere"
- My Runs shows runs where Tafadzwa is the driver
- "Start Run" button visible for scheduled runs assigned to Tafadzwa

### 8. Activity Tab (Placeholder)
**Steps:**
1. Tap on "Activity" tab

**Expected:**
- Title: "Activity"
- Icon: list.bullet.circle
- Text: "Activity Stream"
- Text: "Coming soon"
- Description: "View real-time updates and activity for all runs"

### 9. Settings Tab (Placeholder)
**Steps:**
1. Tap on "Settings" tab

**Expected:**
- Title: "Settings"
- Section: "App Information"
  - Version: 1.0.0 (Demo)
  - Launch Mode: Demo Flow
  - Current User: [current user name]
- Section: "Demo Settings"
  - Text: "Settings features coming soon"

### 10. Run Creation Flow
**Steps:**
1. Go to My Runs tab
2. Tap "+" button
3. Create a run (or use demo run creation)
4. Verify navigation works

**Expected:**
- Run creation sheet opens
- After creation, sheet dismisses
- New run appears in My Runs list
- Can tap run to view details

### 11. Run Details Navigation
**Steps:**
1. From My Runs, tap on a run card
2. Tap "View Details"
3. Verify run detail sheet opens

**Expected:**
- Run detail sheet displays
- Shows run information
- Action buttons based on role
- Can dismiss sheet

### 12. Repeated User Switching
**Steps:**
1. Switch between all 4 users multiple times:
   - Rue → Tafadzwa → TJ → Tawana → Rue
2. After each switch, check My Runs tab

**Expected:**
- No crashes
- My Runs updates correctly for each user
- User switcher reflects current user
- Console logs show successful switches

### 13. Tab Persistence
**Steps:**
1. Navigate to Family tab
2. Open a member profile
3. Dismiss profile
4. Switch to My Runs tab
5. Switch back to Family tab

**Expected:**
- Family list still shows all members
- No reload flicker
- State preserved

### 14. Call Driver Button
**Steps:**
1. Go to Family tab
2. Open Tafadzwa's profile
3. Tap "Call Driver" button

**Expected:**
- iOS prompts to call +1-555-0102
- (In simulator, this may show an error - that's expected)
- In real device, phone app would open

## Edge Cases to Test

### E1. Empty Runs State
**Steps:**
1. Switch to a user with no runs
2. Check My Runs tab

**Expected:**
- Empty state view
- "No runs today" message
- "Create a Run" button

### E2. Multiple Active Runs
**Steps:**
1. Create multiple runs
2. Start one run
3. Check My Runs tab

**Expected:**
- Active run shown in "Active Now" card
- Other runs shown in "Next Up" section

### E3. Role-Based Filtering
**Steps:**
1. Switch to Tafadzwa (Driver)
2. Note runs visible
3. Switch to Rue (Observer)
4. Compare runs visible

**Expected:**
- Tafadzwa sees runs assigned to him as driver
- Rue sees all family runs as observer/admin
- Filtering works correctly

## Performance Checks

### P1. Tab Switching Speed
- Switching between tabs should be instant
- No lag or delay

### P2. Profile Opening Speed
- Member profiles should open immediately
- No loading spinner

### P3. User Switching Speed
- User switching should complete in < 1 second
- My Runs should update immediately

## Known Limitations (Expected Behavior)

1. Activity tab is a placeholder - shows "Coming soon"
2. Settings tab is minimal - only shows app info
3. Call Driver button may not work in simulator
4. Demo family data is hardcoded (Mawere family)
5. User switcher is always visible in Demo Flow mode

## Success Criteria

✅ All 14 test scenarios pass
✅ All 3 edge cases handled correctly
✅ All 3 performance checks pass
✅ No crashes during testing
✅ No console errors (warnings are OK)
✅ UI is responsive and smooth
✅ User switching works reliably
✅ Navigation flows work correctly
