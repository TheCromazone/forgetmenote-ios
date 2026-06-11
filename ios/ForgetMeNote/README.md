# ForgetMeNote — iOS (SwiftUI port)

Native iOS port of the [`zhum/forgetmenote-v2`](https://github.com/zhum/forgetmenote-v2)
Android Kotlin app. See `../upstream/Requirements.md` for the spec and
`Notes/ANDROID_MAPPING.md` for the line-by-line port reference.

## State

**Phase 0** in progress. The Swift files here exist but are not yet attached to
an Xcode project — Xcode itself is being installed. Once Xcode is up, the next
steps are:

1. `xed .` to open this directory in Xcode (or File → New Project... → iOS App →
   place inside `ios/`, name `ForgetMeNote`, SwiftUI + SwiftData, bundle id
   `com.imageorganizer.app.ios`).
2. Drag the existing `Models/`, `Theme/`, `Repository/` folders into the new
   project's source group (uncheck "Copy items if needed").
3. Add the `Podfile` (see below), then `pod install` from the `ios/` directory.
4. Switch to using `ForgetMeNote.xcworkspace` (not the .xcodeproj).

## Planned Podfile

```ruby
platform :ios, '17.0'
use_frameworks!

target 'ForgetMeNote' do
  pod 'GoogleMLKit/ObjectDetection'
  pod 'GoogleMLKit/ImageLabeling'
  pod 'RevenueCat'
  pod 'RevenueCatUI'
end
```

Plus Swift Package Manager additions (added in Xcode → File → Add Packages):
- `https://github.com/weichsel/ZIPFoundation` — for export/import zip handling
- `https://github.com/guoyingtao/Mantis` — for image cropping (ucrop equivalent)
- `https://github.com/groue/GRDB.swift` — for reading imported Android SQLite files

## Directory layout (planned)

```
ios/ForgetMeNote/
├── ForgetMeNoteApp.swift          (@main entry)
├── Models/                        Swift `@Model` types matching Room v12 schema
├── Theme/                         Material 3 color tokens
├── Repository/                    ImageRepository actor and protocol
├── ViewModels/                    @Observable view models, one per Compose ViewModel
├── Views/
│   ├── Screens/                   One file per Android screen
│   └── Components/                Reusable widgets (rectangle selector, tree, etc.)
├── ML/                            ML Kit wrappers (ObjectDetectionService, ImageLabelingService)
├── Camera/                        AVFoundation wrappers (CameraView)
├── Workers/                       BGTaskScheduler reminder logic
├── Notes/                         Port reference docs (this is mining-only)
├── Resources/                     Assets, app icon, launch screen
└── README.md
```

## Things you cannot do without Xcode

- Open or build the project
- Run iOS Simulator
- Use SwiftUI Previews
- Sign and install on a connected iPhone
- `pod install` will succeed without Xcode, but the produced `.xcworkspace` can't be used until Xcode is present

So everything in `Models/`, `Theme/`, `Repository/` exists as plain Swift source
files — when Xcode opens, drag them into the new project and they should compile
without modification.
