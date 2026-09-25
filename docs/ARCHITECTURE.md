# Архитектура Dead Radio

```mermaid
flowchart TD
    Menu[Главное меню] --> Backdrop[3D-фон и три аниме-спутницы]
    Menu -->|Новый забег| Arena[Арена и волны]
    Arena --> Player[Игрок от первого лица]
    Player --> Rifle[Сцена оружия]
    Arena --> Zombie[AI зомби]
    Arena --> Allies[Спутницы]
    Allies --> Zombie
    Player --> HUD[HUD и пауза]
    GameManager[Глобальный счёт и волна] --> HUD
    GameSettings[Сохранённые настройки] --> Menu
    GameSettings --> Arena
    Actions[GitHub Actions] -->|Windows x86_64| Exe[DeadRadio.exe artifact]
```

## Слои

- **UI:** `main_menu.gd` строит главное меню и настройки; `hud.gd` отображает состояние забега, паузу и поражение.
- **Игровая логика:** `arena.gd` создаёт освещение/укрытия и управляет волнами. `player.gd`, `zombie.gd` и `companion.gd` отвечают за движение и действия своих персонажей.
- **Персонажи и оружие:** `anime_survivor.gd` создаёт стилизованные 3D-модели; `rifle.tscn` и `rifle.gd` изолируют вид оружия, отдачу и вспышку.
- **Автозагрузки:** `GameManager` хранит счёт/убийства/волну; `GameSettings` сохраняет звук, разрешение, режим окна, VSync и чувствительность в `user://dead_radio_settings.cfg`.
- **Контент:** WAV/PNG хранятся в `assets/audio/packs/` и `assets/textures/packs/`; игра не загружает ресурсы из сети.
- **Сборка:** `.github/workflows/build-windows.yml` импортирует ресурсы, экспортирует preset `Windows Desktop` и публикует `.exe` как Actions artifact.
