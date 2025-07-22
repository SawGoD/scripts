#!/bin/bash

set -e

echo "📥 Скачиваем последнюю версию Lazydocker..."
bash <(curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh)

echo "🔍 Ищем бинарник lazydocker..."
LAZY_PATH=$(find ~/.local/bin ~/go/bin -type f -name lazydocker 2>/dev/null | head -n 1)

if [[ -z "$LAZY_PATH" ]]; then
  echo "❌ Не удалось найти бинарник lazydocker после установки."
  exit 1
fi

echo "📦 Перемещаем lazydocker в /usr/local/bin..."
sudo mv "$LAZY_PATH" /usr/local/bin/lazydocker
sudo chmod +x /usr/local/bin/lazydocker

echo "✅ Установка завершена! Запусти lazydocker командой:"
echo ""
echo "    lazydocker"
echo ""
