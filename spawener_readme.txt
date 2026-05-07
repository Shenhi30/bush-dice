# Multiplayer Spawner

## Spawner.gd

**Переменные:**
- `network_player` — сцена игрока (PackedScene)

**Функции:**
- `_ready()` — подключает сигнал `peer_connected`
- `spawn_player(id)` — спавнит игрока на сервере