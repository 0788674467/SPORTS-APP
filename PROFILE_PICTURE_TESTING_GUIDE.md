# Profile Picture Testing Guide

## Issue Description
Profile pictures should display in the sidebar navigation for all users (Admin, Coach, Referee). When users register, they're asked to upload a photo, and that photo should appear in the sidebar. Users should also be able to update their photos.

## What Was Fixed

### 1. **Referee Dashboard** (`frontend/lib/features/referee/referee_dashboard.dart`)
- ✅ Added `fetchProfile()` call in `initState` to load profile data on dashboard load
- ✅ Fixed sidebar avatar display to check for empty strings
- ✅ Fixed header avatar display to use dual-source lookup (profile → user metadata)
- ✅ Added complete profile picture upload functionality in Settings
- ✅ Added debug logging to track profile loading

### 2. **Admin Dashboard** (`frontend/lib/features/admin/admin_dashboard.dart`)
- ✅ Already fetches profile in `initState`
- ✅ Fixed all avatar displays to check for empty strings
- ✅ Profile picture upload already implemented

### 3. **Coach Dashboard** (`frontend/lib/features/coach/coach_dashboard.dart`)
- ✅ Already fetches profile in `initState`
- ✅ Avatar display already properly implemented
- ✅ Profile picture upload already implemented

## Testing Steps

### Test 1: New User Registration with Photo
1. **Sign up as a new referee/coach**
   - Go to signup page
   - Fill in all details
   - **Upload a profile picture when prompted**
   - Complete registration
   
2. **Wait for admin approval** (for coach/referee)
   - Admin should see the uploaded photo in the pending approvals list
   
3. **Login after approval**
   - Navigate to the dashboard
   - **Check sidebar**: Your uploaded photo should appear (not just initials)
   - **Check header**: Your photo should appear in the top-right profile dropdown

### Test 2: Existing User Without Photo
1. **Login as existing user** (who registered without photo)
   - Sidebar should show initial letter (e.g., "Q" for "quantum")
   
2. **Update profile picture**:
   - **Referee**: Go to Settings (gear icon in sidebar)
   - **Coach**: Go to Personalization tab
   - **Admin**: Go to Profile section
   
3. **Upload new photo**:
   - Click on the avatar/camera icon
   - Choose Camera or Gallery
   - Select/take a photo
   - Wait for upload confirmation
   
4. **Verify update**:
   - Photo should immediately appear in sidebar
   - Photo should appear in header
   - Refresh page - photo should persist

### Test 3: Update Existing Photo
1. **Login as user with existing photo**
   - Sidebar should show current photo
   
2. **Change photo**:
   - Go to Settings/Personalization/Profile
   - Click on avatar
   - Upload different photo
   
3. **Verify**:
   - New photo replaces old one immediately
   - Changes persist after refresh

## Debugging Steps

### If Photo Doesn't Show After Registration:

1. **Check Browser Console** (F12 → Console tab)
   - Look for debug messages:
     ```
     🔍 Referee Dashboard: Profile fetched
     🔍 Avatar URL: https://...
     🔍 Full Name: quantum
     ```
   
2. **Check if avatar_url is in database**:
   - Open Supabase Dashboard
   - Go to Table Editor → profiles
   - Find your user row
   - Check if `avatar_url` column has a value
   - If empty, the upload during signup failed

3. **Check Supabase Storage**:
   - Go to Storage → avatars bucket
   - Look for folder with your user ID
   - Check if image file exists
   - If missing, storage upload failed

4. **Check Network Tab** (F12 → Network tab):
   - Filter by "avatar" or "upload"
   - Look for failed requests (red)
   - Check error messages

### If Photo Doesn't Update:

1. **Check upload response**:
   - Look for success/error snackbar message
   - Check console for error messages
   
2. **Verify AuthProvider.uploadAvatar()**:
   - Check if method is being called
   - Check if it returns null (success) or error message
   
3. **Check profile refresh**:
   - After upload, `fetchProfile()` should be called
   - Profile data should update in AuthProvider

## Common Issues & Solutions

### Issue 1: "Q" Shows Instead of Photo
**Cause**: Profile not loaded or avatar_url is empty/null

**Solutions**:
- Ensure `fetchProfile()` is called in `initState`
- Check if avatar_url exists in database
- Verify avatar display logic checks for empty strings

### Issue 2: Photo Shows During Upload But Disappears
**Cause**: Upload failed but temporary preview was shown

**Solutions**:
- Check Supabase Storage permissions (RLS policies)
- Verify storage bucket exists and is public
- Check network connectivity
- Look for error messages in console

### Issue 3: Photo Doesn't Update After Upload
**Cause**: Profile not refreshed after upload

**Solutions**:
- Ensure `fetchProfile()` is called after successful upload
- Check if `notifyListeners()` is called in AuthProvider
- Verify `context.watch<AuthProvider>()` is used in widgets

### Issue 4: Different Photo Shows in Different Places
**Cause**: Inconsistent avatar URL sources

**Solutions**:
- Use dual-source lookup: `profile?['avatar_url']` → `user?.userMetadata?['avatar_url']`
- Ensure all avatar displays use the same pattern
- Check if profile table and auth metadata are in sync

## Expected Behavior

### Sidebar Avatar Display:
```dart
CircleAvatar(
  radius: 18,
  backgroundColor: accentColor,
  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty 
      ? NetworkImage(avatarUrl) 
      : null,
  child: avatarUrl == null || avatarUrl.isEmpty
      ? Text(name[0].toUpperCase()) // Show initial
      : null, // Show photo
)
```

### Avatar URL Lookup:
```dart
final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
    ? profile!['avatar_url'] as String
    : ap.user?.userMetadata?['avatar_url'] as String?;
```

## Database Schema

### profiles table:
- `id` (uuid, primary key) - matches auth.users.id
- `full_name` (text)
- `role` (text)
- `avatar_url` (text) - **This stores the profile picture URL**
- `phone` (text)
- `team_name` (text)
- `approval_status` (text)

### Supabase Storage:
- **Bucket**: `avatars`
- **Path**: `{user_id}/avatar_{timestamp}.jpg`
- **Access**: Public (anyone can view)
- **RLS**: Users can only upload to their own folder

## Success Criteria

✅ New users who upload photos during signup see their photos in sidebar
✅ Existing users can update their profile pictures
✅ Photos display consistently across sidebar, header, and profile sections
✅ Photos persist after logout/login
✅ Photos update immediately without page refresh
✅ Fallback to initials when no photo is uploaded
✅ Upload shows loading indicator
✅ Success/error messages display correctly

## Next Steps

1. **Test with real user accounts**:
   - Create new referee account with photo
   - Create new coach account with photo
   - Update existing user photos
   
2. **Verify database**:
   - Check profiles table has avatar_url values
   - Check avatars storage bucket has files
   
3. **Test edge cases**:
   - Very large images (should be compressed)
   - Different image formats (PNG, JPG, HEIC)
   - Network failures during upload
   - Multiple rapid uploads
   
4. **Monitor logs**:
   - Watch console for debug messages
   - Check for any error messages
   - Verify profile fetch is successful

## Support

If issues persist:
1. Check all debug logs in console
2. Verify Supabase Storage is configured correctly
3. Check RLS policies on profiles table and avatars bucket
4. Ensure image_picker package is properly installed
5. Test on different devices/browsers
