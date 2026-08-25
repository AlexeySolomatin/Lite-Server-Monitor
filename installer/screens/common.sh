#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Общие вспомогательные функции мастера установки
#
# Путь:
#   installer/screens/common.sh
#
# Назначение:
#   Вспомогательные функции для экранов мастера установки.
#   Реализует:
#     - Инициализацию TTY (для curl | bash)
#     - Интерактивные диалоги (да/нет, ввод текста, маскированный ввод)
#     - Обработку прерываний (Ctrl+C)
#     - Вызов баннера через ui_banner (из lib/core/ui.sh)
#
# Зависимости:
#   lib/core/ui.sh
#
# Требования:
#   Bash 4+
#
# Совместимость:
#   - Поддерживает запуск через curl | bash (с инициализацией tty)
#   - Цвета автоматически отключаются, если вывод не в TTY или NO_COLOR=1
#
# ShellCheck:
#   Проходит проверку без ошибок и предупреждений
#
# ==============================================================================

set -Eeuo pipefail

# Определяем директорию текущего скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Подключаем UI библиотеку (путь относительно common.sh -> lib/core/ui.sh)
source "${SCRIPT_DIR}/../../lib/core/ui.sh"

# ANSI Цвета для Common (локально, если нужно что-то дополнительно)


# Синхронизируем цвета с ui.sh: если там цвета уже отключены — отключаем и здесь
if [[ -z "${COLOR_RESET:-}" ]]; then
    CLR_RESET=""
    CLR_BOLD=""
    CLR_CYAN=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_RED=""
fi

# -----------------------------------------------------------------------------
# Инициализация TTY для корректного интерактивного ввода
# (например, при запуске через curl | bash)
# -----------------------------------------------------------------------------
wizard_init_tty() {
    if [[ ! -t 0 ]] && [[ -c /dev/tty ]]; then
        exec < /dev/tty
    fi
}

# -----------------------------------------------------------------------------
# Шапка мастера установки (использует ui_banner из ui.sh)
# -----------------------------------------------------------------------------
wizard_header() {
    clear
    ui_banner
}

# -----------------------------------------------------------------------------
# Пауза до нажатия Enter
# -----------------------------------------------------------------------------
wizard_pause() {
    echo
    read -rp "Нажмите Enter для продолжения..." _dummy
}

# -----------------------------------------------------------------------------
# Интерактивный да/нет диалог с поддержкой дефолтного ответа
# Использование: wizard_yes_no "Текст вопроса" [y|n]
# -----------------------------------------------------------------------------
wizard_yes_no() {
    local prompt="$1"
    local default_opt="${2:-y}"
    local hint="[y/N]"

    if [[ "${default_opt}" =~ ^[yY]$ ]]; then
        hint="[Y/n]"
    fi

    while true; do
        read -rp "${CLR_BOLD}${prompt}${CLR_RESET} ${hint}: " answer
        answer="${answer:-${default_opt}}"

        case "${answer}" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *)
                echo -e "${CLR_RED}Пожалуйста, введите 'y' (да) или 'n' (нет).${CLR_RESET}" >&2
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Запрос текстового значения с поддержкой значения по умолчанию
# Использование: wizard_input "Подсказка" "переменная_результата" ["дефолтное_значение"]
# -----------------------------------------------------------------------------
wizard_input() {
    local prompt="$1"
    local var_name="$2"
    local default_val="${3:-}"
    local user_val=""

    if [[ -n "${default_val}" ]]; then
        read -rp "${CLR_BOLD}${prompt}${CLR_RESET} [${CLR_YELLOW}${default_val}${CLR_RESET}]: " user_val
        user_val="${user_val:-${default_val}}"
    else
        while [[ -z "${user_val}" ]]; do
            read -rp "${CLR_BOLD}${prompt}${CLR_RESET}: " user_val
        done
    fi

    eval "${var_name}=\"${user_val}\""
}

# -----------------------------------------------------------------------------
# Скрытый ввод секретов (токены, пароли)
# Использование: wizard_mask_input "Подсказка" "переменная_результата"
# -----------------------------------------------------------------------------
wizard_mask_input() {
    local prompt="$1"
    local var_name="$2"
    local secret_val=""

    while [[ -z "${secret_val}" ]]; do
        read -rsp "${CLR_BOLD}${prompt}${CLR_RESET}: " secret_val
    done
    echo  # перевод строки после скрытого ввода

    eval "${var_name}=\"${secret_val}\""
}

# -----------------------------------------------------------------------------
# Интерактивный чек-лист (Advanced CLI)
#
# Меню выбора с переключением состояний прямо в консоли:
#   - цифра        переключает пункт [ ] <-> [X];
#   - 0            подтверждает выбор;
#   - clear        перерисовывает экран на каждом шаге,
#                  поэтому текст не дублируется.
#
# Использование:
#   wizard_checklist "Заголовок" RESULT_VAR "предвыборка" "Метка подтверждения" "Пункт 1" "Пункт 2" ...
#
# Параметры:
#   $1 - заголовок (подстрока под шапкой менеджера);
#   $2 - имя массива-результата (индексы выбранных пунктов);
#   $3 - изначально отмеченные индексы строкой "0 2 3" (или "");
#   $4 - метка пункта подтверждения;
#   $5+- элементы списка.
#
# Результат:
#   массив ${RESULT_VAR[@]} содержит индексы выбранных элементов
#   (от 0). При пустом выборе массив остается пустым.
#
# Неинтерактивный запуск:
#   если stdin не TTY, автоматически принимается предвыборка.
# -----------------------------------------------------------------------------
wizard_checklist() {
    local title="$1"; shift
    local result_var="$1"; shift
    local defaults_str="${1:-}"; shift
    local confirm_label="${1:-ПОДТВЕРДИТЬ ВЫБОР}"; shift

    local -a items=("$@")

    # Защита имени переменной результата от инъекций в eval
    if [[ ! "${result_var}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo -e "${CLR_RED}Ошибка: недопустимое имя переменной результата.${CLR_RESET}" >&2
        return 1
    fi

    if (( ${#items[@]} == 0 )); then
        echo -e "${CLR_RED}Ошибка: список чек-листа пуст.${CLR_RESET}" >&2
        return 1
    fi

    # Состояния пунктов: 1 = отмечен, 0 = не отмечен
    local -a checked=()
    local i idx
    for ((i = 0; i < ${#items[@]}; i++)); do
        checked+=(0)
    done

    # Применяем предвыборку
    for idx in ${defaults_str}; do
        if [[ "${idx}" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx < ${#items[@]} )); then
            checked[idx]=1
        fi
    done

    # Неинтерактивный запуск: подтверждаем предвыборку без диалога
    # (LSM_CHECKLIST_FORCE_TTY=1 позволяет пройти диалог в тестах)
    if [[ ! -t 0 && "${LSM_CHECKLIST_FORCE_TTY:-0}" != "1" ]]; then
        wizard_checklist_store_result "${result_var}" checked
        echo "(неинтерактивный режим: приняты значения по умолчанию)" >&2
        return 0
    fi

    local msg=""
    local choice zero_pending=false

    while true; do
        # Полная перерисовка экрана: текст не дублируется.
        # Баннер рисуется на каждом кадре, чтобы экран чек-листа
        # был оформлен в едином стиле с остальными экранами мастера.
        command -v clear >/dev/null 2>&1 && clear || printf '\033[2J\033[H'

        if declare -f ui_banner >/dev/null 2>&1; then
            ui_banner
        fi

        echo -e "${CLR_BOLD}${CLR_CYAN}=== ИНТЕРАКТИВНЫЙ МЕНЕДЖЕР УСТАНОВКИ ===${CLR_RESET}"
        echo -e "${CLR_BOLD}${title}${CLR_RESET}"
        echo "Нажимайте цифры для выбора. Нажмите 0 для подтверждения."
        echo "----------------------------------------"

        for ((i = 0; i < ${#items[@]}; i++)); do
            if (( checked[i] == 1 )); then
                printf "%2d) %s %s\n" \
                    "$((i + 1))" \
                    "${CLR_GREEN}${CLR_BOLD}[X]${CLR_RESET}" \
                    "${items[i]}"
            else
                printf "%2d) %s %s\n" \
                    "$((i + 1))" \
                    "[ ]" \
                    "${items[i]}"
            fi
        done

        echo "----------------------------------------"
        echo -e "${CLR_YELLOW}${CLR_BOLD}0) === ${confirm_label} ===${CLR_RESET}"
        echo "----------------------------------------"

        # Строка состояния (ошибка ввода, предупреждения)
        if [[ -n "${msg}" ]]; then
            echo -e "${msg}"
            echo
        fi

        # EOF (закрытый терминал/поток) не должен ронять мастер:
        # принимаем текущий выбор и выходим из диалога.
        if ! read -rp "Ваш выбор: " choice; then
            break
        fi

        if [[ -z "${choice}" ]]; then
            msg=""
            continue
        fi

        if [[ "${choice}" == "0" ]]; then
            local any_selected=false
            for ((i = 0; i < ${#items[@]}; i++)); do
                if (( checked[i] == 1 )); then
                    any_selected=true
                    break
                fi
            done

            if [[ "${any_selected}" == true ]] || [[ "${zero_pending}" == true ]]; then
                break
            fi

            msg="${CLR_YELLOW}Ничего не выбрано. Нажмите 0 еще раз для подтверждения пустого выбора.${CLR_RESET}"
            zero_pending=true
            continue
        fi

        zero_pending=false

        if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#items[@]} )); then
            checked[choice - 1]=$(( 1 - checked[choice - 1] ))
            msg=""
        else
            msg="${CLR_RED}Некорректный ввод: '${choice}'. Введите номер пункта или 0.${CLR_RESET}"
        fi
    done

    wizard_checklist_store_result "${result_var}" checked

    return 0
}

# -----------------------------------------------------------------------------
# Запись результата чек-листа в массив по имени переменной.
# Внутренняя функция wizard_checklist.
# -----------------------------------------------------------------------------
wizard_checklist_store_result() {
    local result_var="$1"
    local -n checked_ref="$2"

    local sel_list="" i

    for ((i = 0; i < ${#checked_ref[@]}; i++)); do
        if (( checked_ref[i] == 1 )); then
            sel_list+="${i} "
        fi
    done

    sel_list="${sel_list% }"

    # sel_list содержит только проверенные числовые индексы через пробел,
    # поэтому прямая подстановка в скобки массива безопасна
    # и дает именно МАССИВ отдельных индексов.
    eval "${result_var}=( ${sel_list} )"

    return 0
}

# -----------------------------------------------------------------------------
# Обработка прерываний (Ctrl+C)
# -----------------------------------------------------------------------------
wizard_trap_init() {
    trap 'echo -e "\n${CLR_YELLOW}${CLR_BOLD}Установка прервана пользователем.${CLR_RESET}" >&2; exit 130' INT TERM
}
