#!/usr/bin/env bash
#
# setup-acer-modes.sh
#
# Installs passwordless KDE menu launchers for Acer Predator laptop modes:
#
# Run from the target user's desktop session:
#   sudo ./setup-acer-modes.sh
#
# Or specify the target account:
#   sudo ./setup-acer-modes.sh eric
#

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this installer with sudo:" >&2
    echo "  sudo $0 [username]" >&2
    exit 1
fi

TARGET_USER="${1:-${SUDO_USER:-}}"

if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
    echo "Error: could not determine the non-root target user." >&2
    echo "Use: sudo $0 <username>" >&2
    exit 1
fi

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
    echo "Error: user '${TARGET_USER}' does not exist." >&2
    exit 1
fi

TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "${TARGET_USER}")"

if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
    echo "Error: home directory for '${TARGET_USER}' was not found." >&2
    exit 1
fi

PLATFORM_PROFILE="/sys/firmware/acpi/platform_profile"
PROFILE_CHOICES="/sys/firmware/acpi/platform_profile_choices"

if [[ ! -e "${PLATFORM_PROFILE}" || ! -r "${PROFILE_CHOICES}" ]]; then
    echo "Error: Acer platform-profile support is unavailable." >&2
    echo "Expected: ${PLATFORM_PROFILE}" >&2
    exit 1
fi

for profile in performance balanced low-power; do
    if ! grep -qw "${profile}" "${PROFILE_CHOICES}"; then
        echo "Error: required Acer profile '${profile}' is unavailable." >&2
        echo "Available profiles:" >&2
        cat "${PROFILE_CHOICES}" >&2
        exit 1
    fi
done

if ! command -v tuned-adm >/dev/null 2>&1; then
    echo "Error: tuned-adm was not found. Install/enable TuneD first." >&2
    exit 1
fi

echo "Installing Acer mode switcher for user: ${TARGET_USER}"
echo "Home directory: ${TARGET_HOME}"

#
# Root-owned mode helper.
#
install -d -m 755 /usr/local/sbin

cat >/usr/local/sbin/acer-mode <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

MAX_PERF_PCT=/sys/devices/system/cpu/intel_pstate/max_perf_pct   # reported only; not managed by this script
PLATFORM_PROFILE=/sys/firmware/acpi/platform_profile   # read-write when the ACPI driver is present; TuneD sets it (drives EC fan curves)

# --- RAPL: auto-detect the CPU package domain (MSR interface) ---
# /sys/class/powercap holds several intel-rapl entries. We want the top-level
# MSR domain whose name is "package-*" (e.g. intel-rapl:0). Deliberately skipped:
#   intel-rapl:X:Y      subdomains (core/uncore/gfx) - energy counters, not limits
#   intel-rapl-mmio:*   MMIO view of the same package - MSR domain is canonical
find_package_rapl() {
    local d b name
    for d in /sys/class/powercap/intel-rapl:*; do
        b=${d##*/}
        [[ $b =~ ^intel-rapl:[0-9]+$ ]] || continue    # skip subdomains
        name=$(cat "$d/name" 2>/dev/null || true)
        if [[ $name == package-* ]]; then
            printf '%s\n' "$d"
            return 0
        fi
    done
    return 1
}

RAPL=$(find_package_rapl || true)
PL1_UW="${RAPL}/constraint_0_power_limit_uw"   # PL1, sustained
PL2_UW="${RAPL}/constraint_1_power_limit_uw"   # PL2, short-term boost

platform_profile_str() {
    if [[ -r "$PLATFORM_PROFILE" ]]; then
        cat "$PLATFORM_PROFILE"
    else
        echo "not available"
    fi
}

max_perf_pct_str() {
    if [[ -r "$MAX_PERF_PCT" ]]; then
        cat "$MAX_PERF_PCT"
    else
        echo "not available"
    fi
}

# tuned-adm active prints "Current active profile: X" (and, with tuned-ppd,
# possibly a second "Current active profile (tuned-adm): Y" line).
active_profile() {
    local p
    p=$(tuned-adm active 2>/dev/null | awk -F': ' '/^Current active profile: /{print $2; exit}') || true
    if [[ -z "$p" ]]; then
        p=$(tuned-adm active 2>/dev/null | awk -F': ' '/^Current active profile/{print $2; exit}') || true
    fi
    echo "${p:-none}"
}

usage() {
    echo "Usage: $0 {performance|low-power|balanced|status}" >&2
    exit 2
}

case "${1:-}" in
    performance)
        TUNED_PROFILE="latency-performance" # While using thermald with the OEM adaptive policy disabled, thermald manages max frequency.
        PL1_W=85
        PL2_W=140
        ;;
    low-power)
        TUNED_PROFILE="powersave"
        PL1_W=40
        PL2_W=70
        ;;
    balanced)
        TUNED_PROFILE="balanced-battery"
        PL1_W=55
        PL2_W=115
        ;;
    status)
        echo "TuneD profile:    $(active_profile)"
        echo "Platform profile: $(platform_profile_str)"
        echo "Max perf pct:     $(max_perf_pct_str)"
        if [[ -n "$RAPL" && -r "$PL1_UW" && -r "$PL2_UW" ]]; then
            echo "RAPL package:     $RAPL"
            echo "PL1 (sustained):  $(( $(cat "$PL1_UW") / 1000000 )) W"
            echo "PL2 (boost):      $(( $(cat "$PL2_UW") / 1000000 )) W"
        else
            echo "PL1/PL2:          RAPL package domain not found or not readable"
        fi
        echo "RAPL topology:"
        for d in /sys/class/powercap/intel-rapl:* /sys/class/powercap/intel-rapl-mmio:*; do
            b=${d##*/}
            [[ $b =~ ^(intel-rapl|intel-rapl-mmio):[0-9]+(:[0-9]+)?$ ]] || continue
            n=$(cat "$d/name" 2>/dev/null) || continue
            mark=""
            [[ $d == "$RAPL" ]] && mark="   <-- managed by this script"
            echo "  $d ($n)$mark"
        done
        exit 0
        ;;
    *)
        usage
        ;;
esac

if [[ -z "$RAPL" ]]; then
    echo "Error: no MSR-based RAPL package domain found in /sys/class/powercap." >&2
    exit 1
fi
if [[ ! -w "$PL1_UW" || ! -w "$PL2_UW" ]]; then
    echo "Error: RAPL power-limit interface unavailable or not writable (need root)." >&2
    exit 1
fi

PL1_MICRO=$(( PL1_W * 1000000 ))
PL2_MICRO=$(( PL2_W * 1000000 ))

echo "Applying TuneD profile: $TUNED_PROFILE"
tuned-adm profile "$TUNED_PROFILE"

# PL2 first: when raising limits, writing PL1 while PL2 is still low lets
# firmware clamp PL1 down to the old PL2.
echo "Applying power limits:  PL2=${PL2_W} W, PL1=${PL1_W} W"
printf '%s\n' "$PL2_MICRO" > "$PL2_UW"
printf '%s\n' "$PL1_MICRO" > "$PL1_UW"

ACTUAL_PL1=$(( $(cat "$PL1_UW") / 1000000 ))
ACTUAL_PL2=$(( $(cat "$PL2_UW") / 1000000 ))

echo
echo "Active configuration:"
echo "  TuneD profile:    $(active_profile)"
echo "  Platform profile: $(platform_profile_str)"
echo "  Max perf pct:     $(max_perf_pct_str)"
echo "  PL1 (sustained):  ${ACTUAL_PL1} W   (requested ${PL1_W} W)"
echo "  PL2 (boost):      ${ACTUAL_PL2} W   (requested ${PL2_W} W)"

if (( ACTUAL_PL1 != PL1_W || ACTUAL_PL2 != PL2_W )); then
    echo "  note: the driver/firmware clamped a requested value; shown values are what the system accepted." >&2
fi
EOF

chown root:root /usr/local/sbin/acer-mode
chmod 755 /usr/local/sbin/acer-mode

#
# Strictly limited passwordless sudo authorization.
#
SUDOERS_FILE="/etc/sudoers.d/acer-mode-${TARGET_USER}"
SUDOERS_TEMP="$(mktemp)"

cat >"${SUDOERS_TEMP}" <<EOF
# Passwordless Acer profile switcher for ${TARGET_USER}.
# This permits only the fixed modes implemented by /usr/local/sbin/acer-mode.
${TARGET_USER} ALL=(root) NOPASSWD: /usr/local/sbin/acer-mode performance, \\
    /usr/local/sbin/acer-mode balanced, \\
    /usr/local/sbin/acer-mode low-power, \\
    /usr/local/sbin/acer-mode status
EOF

chmod 440 "${SUDOERS_TEMP}"

if ! visudo -cf "${SUDOERS_TEMP}"; then
    echo "Error: generated sudoers file did not validate." >&2
    rm -f "${SUDOERS_TEMP}"
    exit 1
fi

install -o root -g root -m 440 "${SUDOERS_TEMP}" "${SUDOERS_FILE}"
rm -f "${SUDOERS_TEMP}"

#
# User-owned launcher wrappers.
#
USER_BIN="${TARGET_HOME}/.local/bin"
APPLICATIONS_DIR="${TARGET_HOME}/.local/share/applications"

install -d -o "${TARGET_USER}" -g "${TARGET_GROUP}" -m 755 "${USER_BIN}"
install -d -o "${TARGET_USER}" -g "${TARGET_GROUP}" -m 755 "${APPLICATIONS_DIR}"

cat >"${USER_BIN}/acer-mode-launcher" <<'EOF'
#!/usr/bin/env bash
#
# User-level launcher. The limited sudo rule permits only valid fixed modes.
#

set -u

MODE="${1:-}"

case "${MODE}" in
    performance)
        TITLE="Acer mode changed"
        MESSAGE="Performance"
        ICON="power-profile-performance"
        ;;
    balanced)
        TITLE="Acer mode changed"
        MESSAGE="Balanced"
        ICON="power-profile-balanced"
        ;;
    low-power)
        TITLE="Acer mode changed"
        MESSAGE="Low-Power"
        ICON="power-profile-power-saver"
        ;;
    *)
        notify-send --urgency=critical \
            "Acer mode was not changed" \
            "Invalid mode requested: ${MODE}"
        exit 2
        ;;
esac

if sudo -n /usr/local/sbin/acer-mode "${MODE}"; then
    notify-send --icon="${ICON}" "${TITLE}" "${MESSAGE}"
else
    notify-send --urgency=critical \
        "Acer mode was not changed" \
        "The restricted sudo authorization is missing or invalid."
    exit 1
fi
EOF

chown "${TARGET_USER}:${TARGET_GROUP}" "${USER_BIN}/acer-mode-launcher"
chmod 755 "${USER_BIN}/acer-mode-launcher"

#
# KDE application launcher entries.
#
cat >"${APPLICATIONS_DIR}/acer-performance.desktop" <<EOF
[Desktop Entry]
Name=Acer: Performance Mode
Comment=Set Acer performance and TuneD latency-performance
Exec=${USER_BIN}/acer-mode-launcher performance
Icon=power-profile-performance
Terminal=false
Type=Application
Categories=Settings;System;
Keywords=acer;performance;gaming;power;
EOF

cat >"${APPLICATIONS_DIR}/acer-balanced.desktop" <<EOF
[Desktop Entry]
Name=Acer: Balanced Mode
Comment=Set Acer balanced and TuneD balanced
Exec=${USER_BIN}/acer-mode-launcher balanced
Icon=power-profile-balanced
Terminal=false
Type=Application
Categories=Settings;System;
Keywords=acer;balanced;power;
EOF

cat >"${APPLICATIONS_DIR}/acer-low-power.desktop" <<EOF
[Desktop Entry]
Name=Acer: Low-Power Mode
Comment=Set Acer low-power and TuneD powersave
Exec=${USER_BIN}/acer-mode-launcher low-power
Icon=power-profile-power-saver
Terminal=false
Type=Application
Categories=Settings;System;
Keywords=acer;battery;low-power;powersave;
EOF

chown "${TARGET_USER}:${TARGET_GROUP}" \
    "${APPLICATIONS_DIR}/acer-performance.desktop" \
    "${APPLICATIONS_DIR}/acer-balanced.desktop" \
    "${APPLICATIONS_DIR}/acer-low-power.desktop"

chmod 644 \
    "${APPLICATIONS_DIR}/acer-performance.desktop" \
    "${APPLICATIONS_DIR}/acer-balanced.desktop" \
    "${APPLICATIONS_DIR}/acer-low-power.desktop"

#
# Test the restricted sudo rule without accepting a password prompt.
#
echo
echo "Testing restricted passwordless sudo access..."

if sudo -u "${TARGET_USER}" sudo -n /usr/local/sbin/acer-mode status >/dev/null; then
    echo "Passwordless mode switching is configured successfully."
else
    echo "Warning: the sudo rule was installed, but its non-interactive test failed." >&2
    echo "Check with: sudo -l -U ${TARGET_USER}" >&2
fi

#
# Refresh KDE's application menu cache if available.
#
if command -v runuser >/dev/null 2>&1 && command -v kbuildsycoca6 >/dev/null 2>&1; then
    runuser -u "${TARGET_USER}" -- kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo
echo "Installation complete."
echo
echo "You can now open the KDE Application Launcher and search for:"
echo "  Acer: Performance Mode"
echo "  Acer: Balanced Mode"
echo "  Acer: Low-Power Mode"
echo
echo "Terminal commands are also available:"
echo "  ${USER_BIN}/acer-mode-launcher performance"
echo "  ${USER_BIN}/acer-mode-launcher balanced"
echo "  ${USER_BIN}/acer-mode-launcher low-power"
echo
echo "Current state:"
cat "${PLATFORM_PROFILE}"
tuned-adm active
