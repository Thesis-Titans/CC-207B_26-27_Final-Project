# LittleSteps

LittleSteps is a Flutter app that helps parents and other caregivers of children aged 0 to 5 plan simple play at home, note what they observe, and get play ideas suited to the child's age. It is the CC 207B final project of Thesis Titans, BSIT 3A, West Visayas State University.

The project includes the Android, iOS, web, Linux, macOS and Windows platform folders. Android is the main target and the one used for the demo; the other platforms build from the same code but are not tested.

The app talks to the shared [LittleSteps API](https://github.com/Thesis-Titans/littlesteps-api). The [React web client](https://github.com/Thesis-Titans/littlesteps-react) of the same system is the visual reference.

## Team

| Member | GitHub |
|---|---|
| Mark Alvin Cadangin (lead) | @markalvincadangin |
| Justin Ace Ardeña | @Justin-Ardena |
| Vincent John Tamaño | @vincenttamano |
| Nherie C. Acebuche | @Lovelly143 |
| Mae Daniella Faith C. Benjamin | @faithbn |

## Core features

1. **Child profiles:** add a child by nickname and birth month; the app works out the age band.
2. **Activity catalog:** browse and filter play activities by age band, domain and setting.
3. **Activity planning:** add activities to a day, then mark them done or skipped.
4. **Milestone prompts:** record what the child has been seen doing. These are observations, not a diagnosis.
5. **Journal:** private notes per child.
6. **Storybooks:** search picture books and keep a family bookshelf.
7. **AI play ideas:** suggests activities for the child's age, time and materials, with a catalog fallback when the AI is unavailable.

"This week" summarizes completed activities and observations.

## Requirements

- Flutter 3.47 (stable) with Dart 3.13
- The LittleSteps API running locally (see its README)
- For Android: an emulator or device on API 34 or newer, and JDK 17 or 21
- For iOS or macOS: a Mac with Xcode
- For web: Chrome

## Setup and run

```bash
cd BSIT-3A/LittleSteps
flutter pub get
flutter run
```

`flutter run` picks a connected device; use `flutter devices` to list them and `flutter run -d chrome` (or another device id) to choose one.

On the Android emulator the app calls the local API at `http://10.0.2.2:5001/demo-littlesteps/asia-southeast1/api`. On other platforms it uses `localhost` instead.

Before opening a pull request:

```bash
dart format .
flutter analyze
flutter test
```

## Folder layout

```text
lib/
├── main.dart       # app entry point
├── models/         # data classes with fromJson
├── routing/        # named routes
├── screens/        # one folder per feature
├── services/       # API client and one service per API area
├── theme/          # colors, spacing and the Material 3 theme
└── widgets/        # shared widgets (loading, empty and error views, cards)
test/               # unit and widget tests
docs/               # AI usage log
android/ ios/ web/ linux/ macos/ windows/   # platform folders made by flutter create
```

## How we work

See [CONTRIBUTING.md](CONTRIBUTING.md) for branches, reviews and the AI usage log.

## Documentation

Product scope, design specification and API reference are in [littlesteps-docs](https://github.com/Thesis-Titans/littlesteps-docs).
