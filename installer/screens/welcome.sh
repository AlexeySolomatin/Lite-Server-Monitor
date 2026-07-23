#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Welcome Screen
# -----------------------------------------------------------------------------

set -Eeuo pipefail

screen_welcome() {
    wizard_header

    echo -e "${CLR_BOLD}Добро пожаловать в мастер установки Lite Server Monitor (LSM)!${CLR_RESET}"
    echo
    echo "LSM — легкая и модульная система мониторинга состояния сервера,"
    echo "дисков, системных ресурсов и служб безопасности."
    echo
    echo "Мастер поможет вам за несколько шагов:"
    echo -e "  ${CLR_CYAN}•${CLR_RESET} Выбрать подходящий режим установки (быстрый или настраиваемый)"
    echo -e "  ${CLR_CYAN}•${CLR_RESET} Включить нужные модули проверки (Disk, SMART, System, Login, Fail2ban и др.)"
    echo -e "  ${CLR_CYAN}•${CLR_RESET} Настроить каналы отправки алертов (Telegram / Email)"
    echo

    wizard_pause
}
