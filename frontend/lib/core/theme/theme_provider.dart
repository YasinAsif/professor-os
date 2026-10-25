import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum DesignSystem {
  journal,    // v2 "The Journal" (2026 Editorial Grid)
  marginalia, // v1 "Marginalia" (Paper Canvas Classic)
}

enum JournalThemeMode {
  light, // "Pressroom Day" (Default)
  dark,  // "Pressroom Night"
}

class ThemeState {
  final DesignSystem designSystem;
  final JournalThemeMode themeMode;

  const ThemeState({
    this.designSystem = DesignSystem.journal,
    this.themeMode = JournalThemeMode.light,
  });

  ThemeState copyWith({
    DesignSystem? designSystem,
    JournalThemeMode? themeMode,
  }) {
    return ThemeState(
      designSystem: designSystem ?? this.designSystem,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const _storage = FlutterSecureStorage();
  static const _designKey = 'prof_os_design_system';
  static const _modeKey = 'prof_os_theme_mode';

  ThemeNotifier() : super(const ThemeState()) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final savedDesign = await _storage.read(key: _designKey);
      final savedMode = await _storage.read(key: _modeKey);

      DesignSystem ds = DesignSystem.journal;
      if (savedDesign == 'marginalia') {
        ds = DesignSystem.marginalia;
      }

      JournalThemeMode tm = JournalThemeMode.light;
      if (savedMode == 'dark') {
        tm = JournalThemeMode.dark;
      }

      state = ThemeState(designSystem: ds, themeMode: tm);
    } catch (_) {}
  }

  Future<void> setDesignSystem(DesignSystem design) async {
    state = state.copyWith(designSystem: design);
    try {
      await _storage.write(
        key: _designKey,
        value: design == DesignSystem.marginalia ? 'marginalia' : 'journal',
      );
    } catch (_) {}
  }

  Future<void> setThemeMode(JournalThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      await _storage.write(
        key: _modeKey,
        value: mode == JournalThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  void toggleDesignSystem() {
    final next = state.designSystem == DesignSystem.journal
        ? DesignSystem.marginalia
        : DesignSystem.journal;
    setDesignSystem(next);
  }

  void toggleThemeMode() {
    final next = state.themeMode == JournalThemeMode.light
        ? JournalThemeMode.dark
        : JournalThemeMode.light;
    setThemeMode(next);
  }
}

final themeStateProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

/// Controls whether the desktop web sidebar is in collapsed (68px icon-only rail)
/// or expanded (240px full academic workspace) mode.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

