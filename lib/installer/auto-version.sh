#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Автоматический расчёт и заморозка версии
# Путь: lib/installer/auto-version.sh
# ==============================================================================

set -Eeuo pipefail

# Поднимаемся на 2 уровня вверх из lib/installer/ в корень репозитория
LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Получаем последний Git-тег (или v0.0.0)
LATEST_TAG=$(git -C "${LSM_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${LATEST_TAG#v}"

# Разбиваем на Major.Minor.Patch
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION%%-*}"

# Коммиты с последнего тега
COMMITS=$(git -C "${LSM_ROOT}" log "${LATEST_TAG}..HEAD" --oneline 2>/dev/null || echo "")

if [[ -z "${COMMITS}" ]]; then
    echo "[INFO] Новых коммитов со времени тега ${LATEST_TAG} не найдено."
    exit 0
fi

BUMP_TYPE="patch"

# Анализируем правила Conventional Commits
if echo "${COMMITS}" | grep -qE "BREAKING CHANGE|!:"; then
    BUMP_TYPE="major"
elif echo "${COMMITS}" | grep -qE "^[a-f0-9]+ feat"; then
    BUMP_TYPE="minor"
fi

case "${BUMP_TYPE}" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "=========================================="
echo " Текущий тег:    ${LATEST_TAG}"
echo " Тип изменений:  ${BUMP_TYPE^^}"
echo " Новая версия:   v${NEW_VERSION}"
echo "=========================================="

# Обновляем файл VERSION в корне репозитория
echo "${NEW_VERSION}" > "${LSM_ROOT}/VERSION"

# В CI/CD режиме или с флагом --non-interactive выходим без вопросов
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]] || [[ "${1:-}" == "--non-interactive" ]]; then
    echo "[INFO] Автоматический режим (CI). Файл VERSION обновлен до ${NEW_VERSION}."
    exit 0
fi

# Интерактивный режим для локального запуска
read -rp "Создать git tag v${NEW_VERSION} и зафиксировать локально? [y/N]: " confirm
if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    git -C "${LSM_ROOT}" add "${LSM_ROOT}/VERSION"
    git -C "${LSM_ROOT}" commit -m "chore(release): bump version to v${NEW_VERSION}" || true
    git -C "${LSM_ROOT}" tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
    echo "[OK] Тег v${NEW_VERSION} создан!"
fi
