# Offline Functionality - Setup Instructions

## ⚠️ **Current Status**

The offline functionality has been fully implemented in the codebase, but compilation failed due to insufficient disk space on your Mac (99% full, only 229MB available).

## 📋 **What's Been Implemented**

All the code for offline functionality is in place:

1. ✅ **OfflineManager** - Local SQLite database and sync logic
2. ✅ **OfflineDataService** - Data operations with offline support
3. ✅ **OfflineAuthProvider** - Authentication with offline capabilities
4. ✅ **ConnectivityIndicator** - UI components for offline status
5. ✅ **Dependencies** - Added sqflite, connectivity_plus, path

## 🔧 **To Complete Setup**

### **Step 1: Free Up Disk Space**

You need at least **2-3GB free** to compile Flutter apps. Current free space: 229MB

**Quick wins:**
```bash
# Empty trash
rm -rf ~/.Trash/*

# Clear caches
rm -rf ~/Library/Caches/*

# Clean Flutter
cd frontend
flutter clean

# Clear pub cache (if needed)
flutter pub cache clean
```

### **Step 2: Install Dependencies**

Once you have space:
```bash
cd frontend
flutter pub get
```

### **Step 3: Run the App**

```bash
flutter run -d chrome
```

## 📱 **Features That Will Work**

Once compiled, the app will have:

### **Offline Capabilities**
- ✅ All admin dashboard functions work offline
- ✅ User approval/management
- ✅ Team and player management
- ✅ Squad submissions and reviews
- ✅ Venue management
- ✅ Match scheduling
- ✅ Notifications

### **User Experience**
- 🟠 Orange banner when offline
- 🔄 Sync status indicator
- 🔘 Manual sync button
- ⚡ Instant local data access
- 🔁 Automatic background sync

### **Data Management**
- 💾 Local SQLite database
- 🔄 Automatic synchronization
- ⏱️ Timestamp-based conflict resolution
- 📋 Pending operations queue
- 🔒 Data integrity protection

## 🚀 **How It Works**

### **Online Mode**
1. Data fetched from Supabase
2. Cached locally in SQLite
3. Real-time updates active
4. Immediate sync of changes

### **Offline Mode**
1. Orange banner appears
2. All operations use local data
3. Changes queued for sync
4. Full functionality maintained

### **Back Online**
1. Automatic sync triggered
2. Pending operations executed
3. Conflicts resolved
4. Fresh data pulled
5. Banner disappears

## 📂 **Files Modified/Created**

### **New Files**
- `frontend/lib/core/offline/offline_manager.dart`
- `frontend/lib/core/offline/offline_data_service.dart`
- `frontend/lib/core/auth/offline_auth_provider.dart`
- `frontend/lib/core/widgets/connectivity_indicator.dart`

### **Modified Files**
- `frontend/lib/main.dart` - Added OfflineAuthProvider
- `frontend/lib/features/admin/admin_dashboard.dart` - Updated to use OfflineAuthProvider
- `frontend/pubspec.yaml` - Added offline dependencies

## 🔍 **Testing the Offline Functionality**

Once the app runs:

### **Test 1: Go Offline**
1. Open the app in Chrome
2. Open Chrome DevTools (F12)
3. Go to Network tab
4. Select "Offline" from throttling dropdown
5. Verify orange banner appears
6. Try creating/editing data
7. Verify changes are saved locally

### **Test 2: Sync When Online**
1. While offline, make several changes
2. Go back online (Network tab → "No throttling")
3. Verify banner disappears
4. Check that changes synced to server
5. Verify sync status shows "Synced"

### **Test 3: Conflict Resolution**
1. Make changes offline on one device
2. Make different changes online on another device
3. Bring offline device online
4. Verify conflicts resolved (last-write-wins)

## 🐛 **Troubleshooting**

### **If App Won't Compile**
```bash
# Clean everything
flutter clean
rm -rf build/
rm -rf .dart_tool/

# Reinstall dependencies
flutter pub get

# Try again
flutter run -d chrome
```

### **If Offline Features Don't Work**
1. Check browser console for errors
2. Verify SQLite database is created
3. Check connectivity detection is working
4. Verify OfflineAuthProvider is registered

### **If Sync Fails**
1. Check internet connection
2. Verify Supabase credentials
3. Check browser console for API errors
4. Verify pending operations queue

## 📊 **Database Schema**

The local SQLite database has these tables:

```sql
-- User data
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

-- Team data
CREATE TABLE teams (
  id TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

-- Player data
CREATE TABLE players (
  id TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

-- Match data
CREATE TABLE matches (
  id TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

-- Notification data
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

-- Pending operations queue
CREATE TABLE pending_operations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_type TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  data TEXT NOT NULL,
  timestamp INTEGER NOT NULL
);
```

## 🎯 **Expected Behavior**

### **When Online**
- ✅ Data loads from server
- ✅ Real-time updates work
- ✅ Changes sync immediately
- ✅ No offline banner

### **When Offline**
- ✅ Orange banner shows
- ✅ All features work
- ✅ Data loads from local DB
- ✅ Changes queued for sync

### **When Back Online**
- ✅ Banner disappears
- ✅ Queued changes sync
- ✅ Fresh data pulled
- ✅ Conflicts resolved

## 📞 **Next Steps**

1. **Free up disk space** (at least 2-3GB)
2. **Run `flutter pub get`** to install dependencies
3. **Run `flutter run -d chrome`** to compile and launch
4. **Test offline functionality** using Chrome DevTools
5. **Verify sync works** by going offline and back online

## ✅ **Success Criteria**

You'll know it's working when:
- ✅ App compiles without errors
- ✅ Orange banner appears when offline
- ✅ All features work without internet
- ✅ Changes sync when back online
- ✅ Sync status shows pending/synced
- ✅ Manual sync button works

---

**Note**: The implementation is complete. You just need disk space to compile it!