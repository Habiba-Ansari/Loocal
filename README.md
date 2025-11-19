# Loocal - Personal & Community Map Discovery

## Overview

Loocal is a social mapping app that lets users create and share their personal travel experiences with the world. Think of it as your digital travel diary meets community guidebook - where every pin tells a story.

### What is Loocal?

Loocal transforms how people discover and share locations. Instead of just seeing generic business listings, users can:
- **Create personal map pins** marking their favorite spots, hidden gems, and memorable experiences
- **Share travel guides** through curated collections of pins
- **Discover authentic recommendations** from real people rather than just commercial listings

Whether it's marking "that amazing street food stall nobody knows about" or creating a "Perfect Saturday in Paris" guide, Loocal makes every map personal and meaningful.

## Features

- 🗺️ **Personal Map Pins** - Save your favorite spots with custom notes and photos
- 🌍 **Public Guides** - Share your travel experiences as public map collections
- 🔍 **Discover Local Gems** - Find authentic recommendations from other travelers
- 📝 **Experience Stories** - Add photos, ratings, and stories to each location
- 👥 **Social Mapping** - Follow other users and see their public pins
- 💾 **Offline Access** - Save your maps for offline use during travels

## Tech Stack
- **Flutter** - Cross-platform framework
- **Firebase** - Authentication & database
- **Google Maps** - Map services
- **Cloud Storage** - For photos and media

## Getting Started

### Prerequisites
- Flutter SDK
- Android Studio/VSCode

### Installation
1. Clone the repo
   ```bash
   git clone https://github.com/yourusername/loocal.git
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the app
   ```bash
   flutter run
   ```

### Build Release
```bash
flutter build apk --release
```

## Setup
1. Add Google Maps API key to `android/app/src/main/AndroidManifest.xml`
2. Configure Firebase for user accounts and data storage

## Common Issues
- Remove duplicate `meta-data` tags from AndroidManifest.xml if build fails
- Ensure Google Maps API key has proper permissions

## License
MIT License
