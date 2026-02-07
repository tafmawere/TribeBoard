# Family Management Features

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
