# Google Sign-In Setup Guide for Tabulation System v7

## ✅ Current Status
- Google Sign-In code is implemented in the app
- Dependencies are properly configured
- UI components are ready

## 🔧 Required Setup Steps

### 1. Firebase Console Configuration
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `tabulation-systemv7`
3. Navigate to **Authentication** > **Sign-in method**
4. Enable **Google** as a sign-in provider
5. Add your **support email** and save

### 2. SHA Certificate Configuration
You need to add SHA fingerprints to your Firebase project:

#### Get SHA1 and SHA256:
```bash
# For debug certificate
cd android
./gradlew signingReport
```

#### Add to Firebase:
1. In Firebase Console, go to **Project Settings** > **Your Android App**
2. Add the SHA1 and SHA256 fingerprints
3. Download the updated `google-services.json`
4. Replace the existing file in `android/app/`

### 3. OAuth 2.0 Client ID Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Navigate to **APIs & Services** > **Credentials**
4. Create OAuth 2.0 Client IDs for:
   - Android (using your package name: `com.example.tabulation_systemv7`)
   - Web (if deploying to web)
   - iOS (if deploying to iOS)

### 4. Updated google-services.json
The current `google-services.json` needs to include OAuth client configuration. After completing steps 1-3, your updated file should contain:

```json
{
  "project_info": {
    "project_number": "135150298843",
    "project_id": "tabulation-systemv7",
    "storage_bucket": "tabulation-systemv7.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:135150298843:android:e0e397a2452c811f3f8efe",
        "android_client_info": {
          "package_name": "com.example.tabulation_systemv7"
        }
      },
      "oauth_client": [
        {
          "client_id": "YOUR_CLIENT_ID",
          "client_type": 1,
          "android_info": {
            "package_name": "com.example.tabulation_systemv7",
            "certificate_hash": "YOUR_SHA1_HERE"
          }
        },
        {
          "client_id": "YOUR_CLIENT_ID",
          "client_type": 3
        }
      ],
      "api_key": [
        {
          "current_key": "AIzaSyD-Yaa7AKXAdmDHwH_nFsGfOwS4KZgllc4"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": [
            {
              "client_id": "YOUR_WEB_CLIENT_ID",
              "client_type": 3
            }
          ]
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

### 5. Testing Checklist
- [ ] Run `flutter clean` and `flutter pub get`
- [ ] Build and run the app
- [ ] Test Google Sign-In button on signup screen
- [ ] Check Firebase Authentication users after sign-in
- [ ] Verify user data is saved in Firestore

### 6. Troubleshooting
If Google Sign-In fails:
1. Check logcat for detailed error messages
2. Verify SHA fingerprints are correctly added
3. Ensure OAuth consent screen is configured
4. Check that the Google Sign-In method is enabled in Firebase
5. Verify the package name matches exactly

### 7. Common Error Fixes
- **Error 10**: SHA fingerprint mismatch - regenerate and re-add SHA
- **Error 12500**: Update Google Play Services on device
- **Error 7**: Check OAuth consent screen configuration

## 🚀 Quick Test Command
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## 📱 Expected Behavior
After setup completion:
1. Google Sign-In button should work on signup screen
2. Users can sign in with Google accounts
3. User data should be saved to Firestore
4. App should navigate to appropriate screen after sign-in
