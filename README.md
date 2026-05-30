# Fitness RPG

A gamified fitness app built in Godot 4.x where real workouts power your RPG adventure.

## Features

- **XP & Leveling** — Earn XP from every workout, level up through ranks (Rookie → Warrior → Champion → Elite → Legend)
- **Boss Battles** — Every 10th workout triggers a boss fight with HP bars and victory rewards
- **Character Sheet** — Track Strength, Endurance, Consistency, Versatility stats with radar chart
- **Smart AI Coach** — AI generates workouts with progressive overload based on your history
- **Target Prescription** — AI prescribes specific weights/reps per exercise based on your data
- **Achievement System** — 14 achievements across milestones, streaks, levels, and boss battles
- **4 Selectable Themes** — Dark RPG, Neon Cyberpunk, Clean Game, Minimal Warrior
- **Streak Tracking** — Daily streak system with fire animation

## Tech Stack

- **Engine:** Godot 4.3+
- **Language:** GDScript
- **Database:** SQLite (via Godot plugin)
- **API:** OpenRouter (AI workout generation + coach)
- **Platforms:** Android, iOS, Desktop

## Project Structure

```
fitness-rpg/
├── project.godot          — Godot project config
├── scenes/                — Scene files (.tscn)
│   ├── main.tscn          — Scene manager
│   ├── title_screen.tscn  — Main menu
│   ├── hub.tscn           — Home dashboard
│   ├── workout.tscn       — Exercise tracking
│   ├── boss_battle.tscn   — 2D boss combat
│   ├── character_sheet.tscn — Stats & radar chart
│   ├── achievements.tscn  — Badge collection
│   ├── settings.tscn      — Theme & preferences
│   ├── routine_list.tscn  — Routine management
│   └── profile_setup.tscn — Initial profile
├── scripts/               — GDScript files
│   ├── game_manager.gd    — Central state (autoload)
│   ├── database.gd        — SQLite wrapper (autoload)
│   ├── gamification.gd    — XP/level/boss calculations
│   ├── ai_client.gd       — OpenRouter API client
│   ├── theme_manager.gd   — 4 selectable themes
│   └── [scene scripts]    — Per-scene logic
└── assets/
    ├── sprites/           — Character & boss sprites (placeholder)
    ├── ui/                — UI elements, icon
    ├── audio/             — SFX & music (placeholder)
    └── fonts/             — Custom fonts (placeholder)
```

## Building for Android

1. Install Godot 4.3+ with Android export templates
2. Set up Android SDK + JDK 17
3. Open project in Godot
4. Project → Export → Android
5. Build APK

## Status

- [x] Core architecture (autoloads, database, navigation)
- [x] Gamification system (XP, levels, streaks, achievements, boss battles)
- [x] AI workout generation with progressive overload
- [x] 4 selectable themes
- [x] All core scenes
- [ ] Art assets (using placeholders)
- [ ] Sound effects & music
- [ ] Polish & animations
- [ ] iOS export config
