#!/bin/sh
# Common helper functions for test scripts
# Usage: source this file from a test script
#   . "$(dirname "$0")/../helpers.sh"

# assert_mapping_value <program> <mapping> <key> <expected>
# Constructs a mapping query URL of the form:
#   http://localhost:3030/testnet/program/<program>/mapping/<mapping>/<key>
# (Base can be overridden with BASE_NODE_URL env var, which should include /testnet if needed)
# Fetches it (silent, fails on HTTP errors), strips newlines and surrounding quotes,
# and compares to the expected value.
# On mismatch prints an error to stderr and returns 1; otherwise prints a pass message.
assert_mapping_value() {
    program="$1"
    mapping="$2"
    key="$3"
    expected="$4"

    if [ -z "$program" ] || [ -z "$mapping" ] || [ -z "$key" ] || [ -z "$expected" ]; then
        echo "Usage: assert_mapping_value <program> <mapping> <key> <expected>" >&2
        return 1
    fi

    # URL-encode a single path segment (bash required)
    urlencode() {
        local s="$1" out="" c i
        for (( i=0; i<${#s}; i++ )); do
            c=${s:i:1}
            case "$c" in
                [a-zA-Z0-9._~-]) out+="$c" ;;
                *) printf -v out '%s%%%02X' "$out" "'$c" ;;
            esac
        done
        printf '%s' "$out"
    }

    encoded_key="$(urlencode "$key")"

    base="${BASE_NODE_URL:-http://localhost:3030/testnet}"
    base="${base%/}"
    url="$base/program/$program/mapping/$mapping/$encoded_key"

    resp="$(curl -fsS "$url" 2>/dev/null || true)"
    resp_clean="$(printf "%s" "$resp" | tr -d '\n"')"
    expected_clean="$(printf "%s" "$expected" | tr -d '\n"')"

    if [ "$resp_clean" != "$expected_clean" ]; then
        echo "Assertion failed ($program/$mapping/$key): expected '$expected' got '$resp'" >&2
        return 1
    fi
    echo "Assertion passed ($program/$mapping/$key)"
    return 0
}

# get_mapping_value <program> <mapping> <key>
# Fetches the mapping value and writes the raw curl response (unchanged) to stdout.
# Returns:
#   0 on success
#   1 on usage error or fetch error
get_mapping_value() {
    program="$1"
    mapping="$2"
    key="$3"

    if [ -z "$program" ] || [ -z "$mapping" ] || [ -z "$key" ]; then
        echo "Usage: get_mapping_value <program> <mapping> <key>" >&2
        return 1
    fi

    urlencode() {
        local s="$1" out="" c i
        for (( i=0; i<${#s}; i++ )); do
            c=${s:i:1}
            case "$c" in
                [a-zA-Z0-9._~-]) out+="$c" ;;
                *) printf -v out '%s%%%02X' "$out" "'$c" ;;
            esac
        done
        printf '%s' "$out"
    }

    encoded_key="$(urlencode "$key")"

    base="${BASE_NODE_URL:-http://localhost:3030/testnet}"
    base="${base%/}"
    url="$base/program/$program/mapping/$mapping/$encoded_key"

    resp="$(curl -fsS "$url")" || {
        echo "Failed to fetch mapping value from $url" >&2
        return 1
    }

    # Output raw curl response
    printf "%s" "$resp"
    return 0
}

#   transact [--expect-fail] command [args...]
# Returns:
#   0 = expected outcome achieved
#   1 = unexpected (error) outcome
transact() {
    local expect_fail=0
    if [[ ${1-} == "--expect-fail" ]]; then
        expect_fail=1
        shift
    fi

    if [[ $# -lt 1 ]]; then
        echo "Usage: transact [--expect-fail] command [args...]" >&2
        return 1
    fi

    # Build command with added flags
    local cmd=("$@")
    cmd+=("--broadcast" "-y")

    # Run and capture all output
    local output
    output="$("${cmd[@]}" 2>&1)"
    local cmd_rc=$?

    echo "$output"

    # Detect failure signature in output
    local detected_fail=0
    if echo "$output" | grep -Eq '❌|Transaction rejected'; then
        detected_fail=1
    fi

    if [[ $expect_fail -eq 0 ]]; then
        # Expect success
        if [[ $cmd_rc -ne 0 || $detected_fail -eq 1 ]]; then
            echo "transact: expected success but detected failure" >&2
            return 1
        fi
        return 0
    else
        # Expect failure
        if [[ $cmd_rc -ne 0 || $detected_fail -eq 1 ]]; then
            return 0
        fi
        echo "transact: expected failure but command succeeded" >&2
        return 1
    fi
}
