#!/bin/bash

# Optional: set NO_COLOR=1 to disable colors.
if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
    BOLD="\033[1m"
    DIM="\033[2m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    RESET="\033[0m"
    CLEAR_LINE="\033[2K\r"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; RESET=""
    CLEAR_LINE=""
fi

usage() {
    cat <<EOF
Usage: $(basename "$0") [--module <name>]

Options:
  --module, -m  Run tests only for the specified module (directory under tests/)
  -h, --help    Show this help
EOF
}

MODULE_FILTER=""

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --module|-m)
            [ -n "${2:-}" ] || { printf "${RED}Error: --module requires a value${RESET}\n" >&2; exit 1; }
            MODULE_FILTER="$2"
            shift 2
            ;;
        --module=*)
            MODULE_FILTER="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf "${RED}Unknown argument: %s${RESET}\n" "$1" >&2
            usage
            exit 1
            ;;
    esac
done

# Log file for failed test outputs (override with TEST_LOG_FILE env var).
LOG_FILE="${TEST_LOG_FILE:-test_failures.log}"
: > "$LOG_FILE"

# Check if snarkos is available
if ! command -v snarkos &> /dev/null; then
    printf "${RED}${BOLD}Error: snarkos is not installed or not in PATH.${RESET}\n"
    printf "Please refer to the README for installation instructions.\n"
    exit 1
fi

# Create devnet directory if it doesn't exist
DEVNET_DIR="./tests/devnet"
mkdir -p "$DEVNET_DIR"

# Resolve module list
if [ -n "$MODULE_FILTER" ]; then
    if [ ! -d "./tests/$MODULE_FILTER" ]; then
        printf "${RED}Error: Module '%s' not found under ./tests${RESET}\n" "$MODULE_FILTER" >&2
        exit 1
    fi
    module_dirs=( "./tests/$MODULE_FILTER" )
else
    module_dirs=()
    while IFS= read -r dir; do
        module_dirs+=("$dir")
    done < <(find ./tests -mindepth 1 -maxdepth 1 -type d | sort)
fi

# If only devnet directory exists (and maybe filtered it out), skip if no real modules
# (Assumes devnet dir name is 'devnet')
filtered_module_dirs=()
for d in "${module_dirs[@]}"; do
    [ "$(basename "$d")" = "devnet" ] && continue
    filtered_module_dirs+=("$d")
done
module_dirs=("${filtered_module_dirs[@]}")

if [ ${#module_dirs[@]} -eq 0 ]; then
    printf "${YELLOW}No test modules to run.${RESET}\n"
    exit 0
fi

# Start leo devnet in background
printf "${CYAN}${BOLD}Starting leo devnet...${RESET}\n"
cd "$DEVNET_DIR"
leo devnet --storage tmp --snarkos "$(which snarkos)" --snarkos-features test_network --clear-storage --num-clients 1 -y > /dev/null 2>&1 &
DEVNET_PID=$!
cd - > /dev/null

# Function to cleanup devnet
cleanup_devnet() {
    if [ -n "$DEVNET_PID" ] && kill -0 "$DEVNET_PID" 2>/dev/null; then
        printf "\n${YELLOW}Stopping leo devnet (PID: %s)...${RESET}\n" "$DEVNET_PID"
        kill "$DEVNET_PID" 2>/dev/null
        wait "$DEVNET_PID" 2>/dev/null
    fi
}

# Trap to ensure devnet is stopped on script exit or interrupt
trap cleanup_devnet EXIT INT TERM

# Give devnet a moment to start
sleep 2
printf "${GREEN}Leo devnet started (PID: %s)${RESET}\n\n" "$DEVNET_PID"

# Wait for devnet to be ready
printf "${CYAN}Waiting for devnet to be ready with height 10...${RESET}\n"
max_attempts=300
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if height=$(curl -s http://localhost:3030/testnet/block/latest 2>/dev/null | grep -o '"height": [0-9]*' | grep -o '[0-9]*' | head -1); then
        if [ -n "$height" ] && [ "$height" -gt 9 ]; then
            printf "${GREEN}Devnet is ready (block height: %s)${RESET}\n\n" "$height"
            break
        else
            printf "${DIM}Waiting... (current height: %s)${RESET}\r" "${height:-0}"
        fi
    fi
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        printf "${RED}Timeout waiting for devnet to be ready${RESET}\n\n"
        exit 1
    fi
    sleep 1
done

total_succeeded_all_modules=0
total_run_all_modules=0
any_test_failed=0

for module_dir in "${module_dirs[@]}"; do
    module_name=$(basename "$module_dir")
    printf "${BOLD}${CYAN}--- Running tests for module: %s ---${RESET}\n" "$module_name"

    test_scripts=()
    while IFS= read -r line; do
        test_scripts+=("$line")
    done < <(find "$module_dir" -name "*.sh" | sort)
    
    if [ ${#test_scripts[@]} -eq 0 ]; then
        printf "${YELLOW}No tests found for this module.${RESET}\n\n"
        continue
    fi

    total_tests_in_module=${#test_scripts[@]}
    printf "Running %s test(s) for %s\n" "$total_tests_in_module" "$module_name"
    succeeded_count_in_module=0

    for script in "${test_scripts[@]}"; do
        test_name=$(basename "$script" .sh)
        indent="    "

        if [ -t 1 ]; then
            printf "${DIM}${indent}⧗ %s - pending...${RESET}\r" "$test_name"
        else
            printf "${indent}Pending: %s\n" "$test_name"
        fi

        output=$(bash "$script" 2>&1)
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            succeeded_count_in_module=$((succeeded_count_in_module + 1))
            if [ -t 1 ]; then
                printf "${CLEAR_LINE}${GREEN}${indent}✓ %s/%s - %s${RESET}\n" "$succeeded_count_in_module" "$total_tests_in_module" "$test_name"
            else
                printf "${indent}PASS %s/%s - %s\n" "$succeeded_count_in_module" "$total_tests_in_module" "$test_name"
            fi
        else
            any_test_failed=1
            timestamp=$(date +"%Y-%m-%d %H:%M:%S")
            {
                printf "==== FAILED TEST ====\n"
                printf "Time: %s\n" "$timestamp"
                printf "Module: %s\n" "$module_name"
                printf "Test: %s\n" "$test_name"
                printf "Script: %s\n" "$script"
                printf "Exit code: %s\n" "$exit_code"
                printf "==== Output start ====\n"
                printf "%s\n" "$output"
                printf "==== Output end ====\n"
                printf "=====================\n\n"
            } >> "$LOG_FILE"

            if [ -t 1 ]; then
                printf "${CLEAR_LINE}${RED}${indent}✗ %s/%s - %s (logged to %s)${RESET}\n" "$succeeded_count_in_module" "$total_tests_in_module" "$test_name" "$LOG_FILE"
            else
                printf "${indent}FAIL %s/%s - %s (logged to %s)\n" "$succeeded_count_in_module" "$total_tests_in_module" "$test_name" "$LOG_FILE"
            fi
        fi
    done

    total_succeeded_all_modules=$((total_succeeded_all_modules + succeeded_count_in_module))
    total_run_all_modules=$((total_run_all_modules + total_tests_in_module))
    
    if [ $succeeded_count_in_module -eq $total_tests_in_module ]; then
        printf "${BOLD}${GREEN}Module summary: %s/%s tests passed.${RESET}\n\n" "$succeeded_count_in_module" "$total_tests_in_module"
    else
        printf "${BOLD}${YELLOW}Module summary: %s/%s tests passed.${RESET}\n\n" "$succeeded_count_in_module" "$total_tests_in_module"
    fi
done

printf "${BOLD}---${RESET}\n"

if [ $total_succeeded_all_modules -eq $total_run_all_modules ]; then
    printf "${BOLD}${GREEN}Overall summary: %s/%s tests passed.${RESET}\n" "$total_succeeded_all_modules" "$total_run_all_modules"
else
    printf "${BOLD}${RED}Overall summary: %s/%s tests passed.${RESET}\n" "$total_succeeded_all_modules" "$total_run_all_modules"
    printf "See failed test outputs in: %s\n" "$LOG_FILE"
fi

exit $any_test_failed