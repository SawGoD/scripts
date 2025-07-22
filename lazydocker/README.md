# 🐳 Lazydocker Install

Скрипт для автоматической установки [lazydocker](https://github.com/jesseduffield/lazydocker) - TUI для управления Docker.

## 📋 Описание

Утилита для визуального управления Docker контейнерами, образами и логами через терминальный интерфейс.

## 🚀 Использование

### Установка одной командой:
```bash
curl -s https://raw.githubusercontent.com/SawGoD/scripts/refs/heads/main/lazydocker/lazydocker_install.sh | bash
```

### Локальная установка:
```bash
chmod +x lazydocker_install.sh
./lazydocker_install.sh
```

## 🎯 Что делает скрипт

- 📥 Скачивает последнюю версию lazydocker
- 🔍 Находит установленный бинарник 
- 📦 Перемещает в `/usr/local/bin/`
- ✅ Делает доступным системно

## 🔧 После установки

Запуск:
```bash
lazydocker
```

## 📋 Требования

- Linux система
- `curl` для скачивания
- `sudo` права для установки в систему 