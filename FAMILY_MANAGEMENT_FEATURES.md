# Family Management Features

> **Historical document (early ROL_MOD, demo-mode era).** Family management has
> since moved to the Supabase backend (`household_memberships`, `household_people`,
> FamilyStore/TribeStore). File paths and the "save to Firebase" enhancement note
> below are outdated. For current models see `docs/02_DOMAIN_MODELS.md`.

## Overview
Added comprehensive family management features for parents/admins to manage their family (tribe) in the Family tab.

## Features for Parents/Admins

### 1. Change Family Name
**Access:** Family tab → Gear icon → Family Settings

**Features:**
- Edit family name in real-time
- Shows current member count
- Displays family ID
- Confirmation dialog before saving
- Changes persist during session

**UI:**
- Family name displayed prominently at top of Family tab
- "Edit" button next to family name
- Form-based editing in settings sheet

### 2. Add Family Members
**Access:** Family tab → "Add Member" card (dashed border) OR Family Settings → Manage Members → Add Family Member

**Features:**
- Enter member's full name (required)
- Optional phone number
- Select role: Observer, Driver, or Admin
- Toggle for Parent/Guardian status
- Real-time permissions preview based on selected role
- Confirmation dialog before adding

**Permissions Preview:**
- Shows all capabilities the new member will have
- Updates dynamically when role changes
- Clear explanation of each role

**UI:**
- Dashed border card in member grid
- Plus icon with "Add Member" label
- Full-screen form for member details

### 3. Remove Family Members
**Access:** Family Settings → Manage Members → Minus icon on member row

**Features:**
- Remove any family member except yourself
- Cannot remove if only 1 member remains
- Immediate removal without confirmation (can be changed)
- Member list updates automatically

**Restrictions:**
- Can't remove yourself
- Can't remove last family member
- Only admins can access this feature

### 4. Change Member Roles
**Access:** Family Settings → Manage Roles

**Features:**
- View all family members with current roles
- Segmented picker for each member: Driver, Observer, Admin
- Change any member's role except your own
- Confirmation dialog before role change
- Immediate permission updates
- If changing current user's role, updates their context

**Role Options:**
- **Driver:** Can create and drive runs, track all family runs
- **Observer:** Can view and track all family runs
- **Admin:** Full access - manage family, create/drive runs, change settings

**UI:**
- List view with member avatars
- Current role displayed below name
- Segmented control for role selection
- Disabled for current user (can't change own role)
- Confirmation alert with member name and new role

## Access Control

### Who Can Access These Features?
- **Parents** (Rue, Tafadzwa) - Full access
- **Admins** - Full access
- **Children/Observers** - No access (features hidden)

### Visual Indicators:
- Gear icon in toolbar (admins only)
- Family name header with edit button (admins only)
- "Add Member" card in grid (admins only)
- Settings navigation links (admins only)

## User Experience

### Family Tab Layout (Admin View):
```
┌─────────────────────────────────────┐
│ Family                    [Gear]    │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ Mawere Family        [Edit]     │ │
│ │ 4 members                       │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ℹ️ Demo family — can be removed    │
│                                     │
│ ┌──────────┐  ┌──────────┐        │
│ │   RM     │  │   TM     │        │
│ │ Rue      │  │ Tafadzwa │        │
│ │ Parent   │  │ Parent   │        │
│ └──────────┘  └──────────┘        │
│                                     │
│ ┌──────────┐  ┌──────────┐        │
│ │   TJ     │  │   TW     │        │
│ │ TJ       │  │ Tawana   │        │
│ │ Child    │  │ Child    │        │
│ └──────────┘  └──────────┘        │
│                                     │
│ ┌──────────┐                       │
│ │    +     │                       │
│ │ Add      │                       │
│ │ Member   │                       │
│ └──────────┘                       │
└─────────────────────────────────────┘
```

### Family Settings Screen:
```
┌─────────────────────────────────────┐
│ < Cancel  Family Settings           │
├─────────────────────────────────────┤
│ FAMILY INFORMATION                  │
│ Family Name      [Mawere Family]    │
│ Members                          4  │
│ Family ID        demo-family-...    │
│                                     │
│ FAMILY MANAGEMENT                   │
│ > Manage Members                    │
│ > Manage Roles                      │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │      Save Changes               │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Add Member Screen:
```
┌─────────────────────────────────────┐
│ < Cancel  Add Family Member         │
├─────────────────────────────────────┤
│ MEMBER INFORMATION                  │
│ Full Name        [Enter name]       │
│ Phone Number     [Optional]         │
│ Parent/Guardian  [ ] Toggle         │
│                                     │
│ ROLE                                │
│ [Observer][Driver][Admin]           │
│ Can view and track all family runs  │
│                                     │
│ PERMISSIONS PREVIEW                 │
│ ✓ Can create runs                   │
│ ✓ Can track runs                    │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │    Add Family Member            │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Manage Roles Screen:
```
┌─────────────────────────────────────┐
│ < Back    Manage Roles              │
├─────────────────────────────────────┤
│ CHANGE MEMBER ROLES                 │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  RM  Rue Mawere                 │ │
│ │      Current: Observer          │ │
│ │  [Driver][Observer][Admin]      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  TM  Tafadzwa Mawere            │ │
│ │      Current: Driver            │ │
│ │  [Driver][Observer][Admin]      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Note: Changing a member's role will │
│ update their permissions immediately│
└─────────────────────────────────────┘
```

## Implementation Details

### Data Management:
- Member roles tracked in `FamilyViewModel.memberRoles` dictionary
- Family name stored in `FamilyViewModel.familyName`
- Changes persist during app session (not saved to backend in demo)
- Dynamic member IDs generated for new members

### Role Change Flow:
1. Admin selects new role from segmented picker
2. Confirmation alert displays
3. On confirmation:
   - Update `memberRoles` dictionary
   - Reload family members list
   - If current user, update role context
   - Refresh HomeDashboardViewModel
4. UI updates immediately

### Add Member Flow:
1. Admin fills in member details
2. Selects role and parent status
3. Permissions preview updates
4. Confirmation alert displays
5. On confirmation:
   - Generate unique member ID
   - Create FamilyMemberDisplay
   - Add to familyMembers array
   - Store role in memberRoles
6. Member appears in grid immediately

### Remove Member Flow:
1. Admin taps minus icon
2. Validation checks:
   - Not removing self
   - Not last member
3. Remove from familyMembers array
4. Remove from memberRoles dictionary
5. UI updates immediately

## Testing Scenarios

### Test 1: Change Family Name
1. Login as Rue or Tafadzwa (parent)
2. Go to Family tab
3. Tap gear icon → Family Settings
4. Change family name to "Smith Family"
5. Tap "Save Changes"
6. Verify family name updates in header

### Test 2: Add New Member
1. Login as parent
2. Go to Family tab
3. Tap "Add Member" card
4. Enter name: "Alex Smith"
5. Enter phone: "+1-555-0103"
6. Select role: Driver
7. Toggle Parent/Guardian: ON
8. Verify permissions preview shows driver capabilities
9. Tap "Add Family Member"
10. Verify Alex appears in grid

### Test 3: Change Member Role
1. Login as parent
2. Go to Family tab → Gear → Manage Roles
3. Find TJ in list
4. Change role from Observer to Driver
5. Confirm in alert
6. Verify TJ's role updates
7. Go back to Family tab
8. Tap on TJ's card
9. Verify profile shows Driver badge and capabilities

### Test 4: Remove Member
1. Login as parent
2. Go to Family tab → Gear → Manage Members
3. Find newly added member
4. Tap minus icon
5. Verify member removed from list
6. Go back to Family tab
7. Verify member no longer in grid

### Test 5: Access Control
1. Login as TJ (child)
2. Go to Family tab
3. Verify NO gear icon in toolbar
4. Verify NO family name header
5. Verify NO "Add Member" card
6. Verify only member cards visible

## Known Limitations

1. **Demo Mode:** Changes don't persist to backend (in-memory only)
2. **No Undo:** Removed members can't be restored (would need to re-add)
3. **No Validation:** Phone numbers not validated for format
4. **No Invitations:** Adding members doesn't send actual invites
5. **No Permissions Check:** Assumes parents are always admins

## Future Enhancements

1. **Backend Integration:** Save changes to Firebase
2. **Email/SMS Invitations:** Send actual invites to new members
3. **Member Photos:** Upload and display profile pictures
4. **Audit Log:** Track who made what changes and when
5. **Undo/Redo:** Allow reverting recent changes
6. **Bulk Operations:** Add/remove multiple members at once
7. **Role Templates:** Pre-defined role configurations
8. **Permission Customization:** Fine-grained permission control

## Files Modified/Created

### New Files:
1. `Tribeboard/Views/Family/FamilySettingsView.swift` - Family settings, manage members, manage roles
2. `Tribeboard/Views/Family/AddFamilyMemberView.swift` - Add new family member form

### Modified Files:
1. `Tribeboard/Views/Family/FamilyView.swift` - Added family name header, add member card, settings access
2. `Tribeboard/ViewModels/Family/FamilyViewModel.swift` - Added CRUD operations, role tracking, admin checks

## Summary

Parents and admins now have full control over their family management:
- ✅ Change family (tribe) name
- ✅ Add new family members with role selection
- ✅ Remove family members (with restrictions)
- ✅ Change member roles dynamically
- ✅ View and manage all family settings
- ✅ Proper access control (admin-only features)
- ✅ Real-time UI updates
- ✅ Confirmation dialogs for important actions
- ✅ Clear permissions preview for new members

All features are intuitive, well-organized, and follow iOS design patterns.

---

## Member Profile UI Redesign

### Overview
The Family Member Profile screen has been redesigned to match TribeBoard's visual language with soft, rounded cards, calm colors, and clear hierarchy. This is a UI-only update with no backend changes.

### Visual Design

**Design System:**
- Off-white background (#F9FAFB)
- White cards with 20pt corner radius
- Subtle shadows for depth
- Consistent 16pt spacing between cards
- 20pt internal card padding
- Soft blue accents (#6366F1)

**Card Structure:**
```
┌─────────────────────────────────────┐
│ [Back]        Profile        [Done] │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │         [Avatar]                │ │
│ │      Sarah Doe                  │ │
│ │      Mom                        │ │
│ │  [ADMIN] [DRIVER]               │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  Permissions                    │ │
│ │  ✓ Can create runs              │ │
│ │  ✓ Can start/drive runs         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  Location Sharing               │ │
│ │  ● Enabled                      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  Contact                        │ │
│ │  📞 +1-555-0100                 │ │
│ │  [Call Driver]                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  Activity                       │ │
│ │  🚗 2 assigned runs             │ │
│ │  👁 5 visible runs              │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Components

**Reusable Components Created:**
1. **ProfileCard** - White card wrapper with shadow and padding
2. **SectionHeader** - 17pt semibold section titles
3. **RoleBadge** - Colored role indicators with uppercase text
4. **PermissionRow** - Checkmark + permission text
5. **StatRow** - Icon + statistic text

**Design System Constants:**
- Colors: Screen background, card background, primary blue, status colors, badge colors, text colors
- Spacing: 4pt, 8pt, 12pt, 16pt, 20pt, 24pt, 32pt
- Corner Radius: Small (8pt), Medium (12pt), Large (20pt), XLarge (24pt)

### Card Details

**1. Header Card**
- 80x80pt circular avatar with deterministic color
- Member name (22pt bold)
- Relationship label ("Mom" or "Child")
- Role badges in flow layout (wraps to multiple rows)
- Center-aligned layout

**2. Permissions Card**
- Lists all capabilities from member's roles
- Green checkmark icon (14pt)
- Permission text (15pt)
- 12pt spacing between items

**3. Location Sharing Card**
- Status indicator: 8pt circle (green=enabled, gray=disabled)
- Status text: "Enabled" or "Disabled"
- Description: "Used for real-time tracking during runs"

**4. Contact Card**
- Phone icon (16pt, info blue) + phone number
- "Call Driver" button (full width, 48pt height)
- Only shows button if member has Driver role
- Falls back to "No contact information" if no phone

**5. Activity Card**
- Assigned runs stat (drivers only) with car icon
- Visible runs stat (all members) with eye icon
- 12pt spacing between rows
- Data from viewModel.getRunStats()

**6. Demo Card** (Demo mode only)
- Orange section header "Demo Only"
- "View as this user" button
- Caption explaining purpose
- Only visible when AppConfig.isDemoFlowEnabled

### Accessibility Features

**VoiceOver Labels:**
- Avatar: "Profile picture for [Name]"
- Role badges: "[Role] role"
- Permissions: "Permission: [capability]"
- Location status: "Location sharing [enabled/disabled]"
- Call button: "Call [Name]"
- Demo button: "Switch to [Name]'s view"

**Dynamic Type:**
- All text scales with system font size
- Minimum touch targets: 44x44pt
- Badges wrap to multiple lines if needed

**Color Contrast:**
- Text on white meets WCAG AA standards
- Status indicators use text + icon (not color alone)

### Implementation Details

**Files Modified:**
- `MemberProfileView.swift` - Complete redesign with card-based layout
- `DesignSystem.swift` - Added corner radius constants
- `FamilyMemberDisplay.swift` - Added isLocationSharingEnabled field

**Files Created:**
- `ProfileCard.swift` - Reusable card wrapper
- `SectionHeader.swift` - Reusable section header
- `RoleBadge.swift` - Reusable role badge
- `PermissionRow.swift` - Reusable permission row
- `StatRow.swift` - Reusable stat row

**Helper Functions:**
- `avatarColor` - Deterministic color selection based on user ID hash
- `badgeColor(for:)` - Maps badge color enum to design system colors
- `FlowLayout` - Custom layout for wrapping badges

### Testing Scenarios

**Visual Testing:**
- ✓ Profile displays correctly for parent with Admin + Driver roles
- ✓ Profile displays correctly for child with Observer role
- ✓ Avatar colors are consistent for same user
- ✓ Badges wrap correctly with many roles
- ✓ Cards have proper spacing and shadows
- ✓ Text is readable and properly sized

**Interaction Testing:**
- ✓ "Done" button dismisses profile
- ✓ "Call Driver" button initiates phone call
- ✓ Demo "Switch User" shows confirmation alert
- ✓ Demo switch updates context and dismisses
- ✓ ScrollView scrolls smoothly

**Edge Cases:**
- ✓ Profile handles missing phone number gracefully
- ✓ Profile handles long names without breaking layout
- ✓ Profile handles many role badges with wrapping
- ✓ Demo section only appears when demo mode enabled

### Design Goals Achieved

✅ **Visual Consistency** - Matches TribeBoard's design language
✅ **Clarity** - Member's roles and permissions are immediately clear
✅ **Usability** - Profile loads quickly, navigation is intuitive
✅ **Emotional Tone** - Calm, reassuring, family-safe, premium but approachable
