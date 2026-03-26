# Logo and Title Update Plan for Web

## Steps:
- [x] 1. Update web/index.html (title, meta description, apple title)
- [x] 2. Update web/manifest.json (name, short_name, description)
- [x] 3. Update pubspec.yaml (description)
- [x] 4. Run `flutter pub get && flutter pub run flutter_launcher_icons:main` to generate custom icons for all platforms including web/favicon.png and web/icons/
- [x] 5. Run `flutter build web --release` to build with updates
- [ ] 6. Test by opening build/web/index.html or deploying

All steps complete. Web app now uses custom name "Tabulation System" and logo from assets/icon.png (generated via flutter_launcher_icons).

