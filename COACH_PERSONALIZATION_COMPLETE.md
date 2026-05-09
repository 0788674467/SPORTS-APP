# Coach Profile & Team Personalization - Implementation Complete ✅

## Overview
The coach dashboard now includes full personalization capabilities, allowing coaches to customize their individual accounts and team branding. All features are fully implemented and integrated with Supabase.

---

## Features Implemented

### 1. **Team Branding Section**
**Location:** Coach Dashboard → Settings → Team Branding

**Capabilities:**
- **Upload Team Badge/Logo**
  - Click the badge area to select an image from gallery
  - Preview shows before saving
  - Automatically uploads to Supabase Storage (`team_logos` bucket)
  - Generates public URL and saves to `teams.logo_url`

- **Change Team Name**
  - Text field to edit team name
  - Syncs to:
    - `teams.name` table
    - `profiles.team_name` (for coach's profile)
    - Auth user metadata (for consistency)

**Backend Methods:**
- `uploadTeamLogo(teamId, imageSource)` - Uploads logo to storage and updates team
- `updateTeam(teamId, name, logoUrl)` - Updates team details and syncs to profiles

---

### 2. **Coach Profile Section**
**Location:** Coach Dashboard → Settings → Coach Profile

**Capabilities:**
- **Update Profile Photo**
  - Click avatar to open camera/gallery picker
  - Supports both camera capture and gallery selection
  - Automatically uploads to Supabase Storage (`avatars` bucket)
  - Generates public URL and saves to `profiles.avatar_url`
  - Shows loading indicator during upload
  - Instant feedback with success/error notification

- **Edit Full Name**
  - Text field with person icon
  - Syncs to:
    - `profiles.full_name`
    - Auth user metadata

- **Edit Phone Number**
  - Phone-formatted input field
  - Saves to `profiles.phone`

**Backend Methods:**
- `uploadAvatar(imageSource)` - Uploads avatar and updates profile
- `updateProfile(fullName, phone, avatarIndex)` - Updates profile fields and auth metadata
- `fetchProfile()` - Refreshes profile data from database

---

### 3. **Change Password Section**
**Location:** Coach Dashboard → Settings → Change Password

**Capabilities:**
- **New Password Field**
  - Visibility toggle (show/hide password)
  - Minimum 6 characters validation
  - Secure input field

- **Confirm Password Field**
  - Visibility toggle
  - Validates match with new password
  - Shows error if passwords don't match

- **Password Requirements**
  - Minimum 6 characters
  - Must match confirmation field
  - Clear validation messages

**Backend Methods:**
- `updatePassword(newPassword)` - Updates password via Supabase Auth

---

### 4. **Appearance Section**
**Location:** Coach Dashboard → Settings → Appearance

**Capabilities:**
- **Theme Toggle**
  - Switch between light and dark backgrounds
  - Affects entire dashboard UI
  - Preference stored in local state

---

## UI/UX Features

### Settings Card Design
- **Gradient Headers** - Each section has a unique gradient color scheme:
  - Team Branding: Green gradient
  - Coach Profile: Blue gradient
  - Change Password: Dark slate gradient
  - Appearance: Purple gradient

- **Icon Indicators** - Each section has a relevant icon
- **Descriptive Subtitles** - Clear explanation of what each section does
- **Responsive Layout** - Works on mobile and desktop

### Form Elements
- **Input Fields** - Consistent styling with:
  - Icon prefixes
  - Filled background
  - Focus states with green accent
  - Proper spacing and padding

- **Image Upload Zones**
  - Animated containers showing preview
  - "TAP TO UPLOAD" hint text
  - Visual feedback on selection
  - Border color changes on selection

- **Buttons**
  - Loading states with spinner
  - Disabled states when loading
  - Icon + text labels
  - Consistent styling per section

### Feedback & Notifications
- **Snackbars** - Floating notifications for:
  - Success messages (green)
  - Error messages (red)
  - Warning messages (orange)
  - Custom styling with icons

- **Loading Indicators**
  - Circular progress spinners
  - Disabled button states during operations
  - Clear visual feedback

---

## Data Flow & Synchronization

### Profile Updates
```
Coach Updates Profile
    ↓
updateProfile() called
    ↓
Updates profiles table
    ↓
Updates auth.user_metadata
    ↓
fetchProfile() refreshes local state
    ↓
UI updates with new data
```

### Team Updates
```
Coach Updates Team
    ↓
updateTeam() called
    ↓
Updates teams table
    ↓
Syncs team_name to profiles table
    ↓
Updates auth.user_metadata
    ↓
_loadSquad() refreshes team data
    ↓
UI updates with new branding
```

### Avatar Upload
```
Coach Selects Photo
    ↓
uploadAvatar() called
    ↓
Uploads to avatars bucket
    ↓
Gets public URL
    ↓
Updates profiles.avatar_url
    ↓
fetchProfile() refreshes
    ↓
Avatar displays in sidebar & header
```

### Team Logo Upload
```
Coach Selects Logo
    ↓
uploadTeamLogo() called
    ↓
Uploads to team_logos bucket
    ↓
Gets public URL
    ↓
updateTeam() saves URL
    ↓
_loadSquad() refreshes
    ↓
Logo displays in overview banner
```

---

## Integration Points

### Sidebar & Header
- Coach name and team name display
- Avatar shows in profile card
- Edit icon links to Settings
- Real-time updates when profile changes

### Overview Dashboard
- Team badge displays in welcome banner
- Coach photo shows in banner
- Team name displays
- Updates reflect immediately after save

### Squad Management
- Team name used for squad submission
- Team ID used for player registration
- Logo displays in team context

---

## Supabase Tables & Storage

### Tables Used
- **profiles** - Stores full_name, phone, avatar_url, team_name
- **teams** - Stores name, logo_url, coach_id
- **auth.users** - Stores user_metadata with team_name, full_name

### Storage Buckets
- **avatars** - Coach profile photos
  - Path: `{user_id}/avatar_{timestamp}.jpg`
  - Public access enabled

- **team_logos** - Team badges
  - Path: `team_{team_id}/logo_{timestamp}.jpg`
  - Public access enabled

---

## Error Handling

### Validation
- Team not found check before upload
- Password length validation (min 6 chars)
- Password match validation
- Empty field checks

### User Feedback
- Clear error messages
- Success confirmations
- Loading states
- Retry capability

### Edge Cases
- Profile not initialized → Loads from database
- Team not found → Shows warning and reloads
- Upload failures → Shows error message
- Network issues → Handled gracefully

---

## Testing Checklist

- [x] Upload team badge/logo
- [x] Change team name
- [x] Update profile photo
- [x] Edit full name
- [x] Edit phone number
- [x] Change password
- [x] Toggle theme
- [x] Verify data syncs to database
- [x] Verify avatar shows in sidebar
- [x] Verify team logo shows in overview
- [x] Test on mobile and desktop
- [x] Test error handling
- [x] Test loading states

---

## Files Modified

### Frontend
- `frontend/lib/features/coach/coach_dashboard.dart` - Complete implementation
- `frontend/lib/core/auth/auth_provider.dart` - Backend methods

### No Backend Changes Required
All functionality uses existing Supabase tables and storage buckets.

---

## How to Use

### For Coaches
1. Navigate to Coach Dashboard
2. Click Settings (gear icon in sidebar or navigation)
3. Scroll to desired section:
   - **Team Branding** - Upload badge and change team name
   - **Coach Profile** - Update photo, name, and phone
   - **Change Password** - Update account password
   - **Appearance** - Toggle theme
4. Make changes and click Save button
5. Receive confirmation notification

### For Admins
- Can view coach profiles in Admin Dashboard
- Can see team branding in team management
- Can approve/reject squads with team information

---

## Future Enhancements

Potential additions:
- Team description/bio
- Coach bio/credentials
- Social media links
- Team colors customization
- Multiple team support
- Profile visibility settings
- Notification preferences

---

## Status: ✅ COMPLETE & READY FOR USE

All features are implemented, tested, and integrated with the backend. The coach personalization system is fully functional and provides a complete user experience for managing individual accounts and team branding.
