#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Автоматический расчёт и заморозка версии
# Путь: lib/installer/auto-version.sh
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Проверяем наличие тегов
LATEST_TAG=$(git -C "${LSM_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "${LATEST_TAG}" ]]; then
    # Если тегов нет совсем — берем историю с самого первого коммита
    echo "[INFO] Теги не найдены. Начинаем с версии v0.0.0"
    LATEST_TAG="v0.0.0"
    CURRENT_VERSION="0.0.0"
    COMMITS=$(git -C "${LSM_ROOT}" log --oneline 2>/dev/null || echo "")
else
    CURRENT_VERSION="${LATEST_TAG#v}"
    COMMITS=$(git -C "${LSM_ROOT}" log "${LATEST_TAG}..HEAD" --oneline 2>/dev/null || echo "")
fi

if [[ -z "${COMMITS}" ]]; then
    echo "[INFO] Новых коммитов со времени тега ${LATEST_TAG} не найдено."
    exit 0
fi

BUMP_TYPE="patch"

# Анализируем сообщения коммитов
if echo "${COMMITS}" | grep -qE "BREAKING CHANGE|!:"; then
    BUMP_TYPE="major"
elif echo "${COMMITS}" | grep -qE "^[a-f0-9]+ feat"; then
    BUMP_TYPE="minor"
fi

# Если текущая версия 0.0.0 и это первый запуск — ставим 0.1.0
if [[ "${CURRENT_VERSION}" == "0.0.0" ]]; then
    NEW_VERSION="0.1.0"
else
    IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION%%-*}"
    case "${BUMP_TYPE}" in
        major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
        patch) PATCH=$((PATCH + 1)) ;;
    esac
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi

echo "=========================================="
echo " Текущий тег:    ${LATEST_TAG}"
echo " Тип изменений:  ${BUMP_TYPE^^}"
echo " Новая версия:   v${NEW_VERSION}"
echo "=========================================="

# Обновляем файл VERSION
echo "${NEW_VERSION}" > "${LSM_ROOT}/VERSION"

if [[ "${GITHUB_ACTIONS:-false}" == "true" ]] || [[ "${1:-}" == "--non-interactive" ]]; then
    echo "[INFO] Автоматический режим (CI). Файл VERSION обновлен до ${NEW_VERSION}."
    exit 0
fi

read -rp "Создать git tag v${NEW_VERSION} и зафиксировать локально? [y/N]: " confirm
if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    git -C "${LSM_ROOT}" add "${LSM_ROOT}/VERSION"
    git -C "${LSM_ROOT}" commit -m "chore(release): bump version to v${NEW_VERSION}" || true
    git -C "${LSM_ROOT}" tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
    echo "[OK] Тег v${NEW_VERSION} создан!"
fi
