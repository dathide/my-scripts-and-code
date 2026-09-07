#!/usr/bin/env bash
#
# setup-acer-modes.sh
#
# Installs passwordless KDE menu launchers for Acer Predator laptop modes:
#
#   Performance: Acer "performance" + TuneD "latency-performance"
#   Balanced:    Acer "balanced"    + TuneD "balanced"
#   Low Power:   Acer "low-power"   + TuneD "powersave"
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
#
# Root-only helper used by the Acer desktop launchers.
#

set -euo pipefail

PLATFORM_PROFILE="/sys/firmware/acpi/platform_profile"

if [[ ! -w "${PLATFORM_PROFILE}" ]]; then
    echo "Error: Acer platform-profile interface is unavailable." >&2
    exit 1
fi

case "${1:-}" in
    performance)
        TUNED_PROFILE="latency-performance"
        ACER_PROFILE="performance"
        DESCRIPTION="Performance + TuneD latency-performance"
        ;;
    balanced)
        TUNED_PROFILE="balanced"
        ACER_PROFILE="balanced"
        DESCRIPTION="Balanced + TuneD balanced"
        ;;
    low-power)
        TUNED_PROFILE="powersave"
        ACER_PROFILE="low-power"
        DESCRIPTION="Low-power + TuneD powersave"
        ;;
    status)
        echo "Acer platform profile: $(cat "${PLATFORM_PROFILE}")"
        echo "TuneD profile:        $(tuned-adm active)"
        exit 0
        ;;
    *)
        echo "Usage: $0 {performance|balanced|low-power|status}" >&2
        exit 2
        ;;
esac

echo "Applying TuneD profile: ${TUNED_PROFILE}"
tuned-adm profile "${TUNED_PROFILE}"

echo "Applying Acer firmware profile: ${ACER_PROFILE}"
printf '%s\n' "${ACER_PROFILE}" >"${PLATFORM_PROFILE}"

echo
echo "Active configuration:"
echo "  Acer platform profile: $(cat "${PLATFORM_PROFILE}")"
echo "  TuneD profile:        $(tuned-adm active)"
echo "  Selected mode:        ${DESCRIPTION}"
EOF

chown root:root /usr/local/sbin/acer-mode
chmod 755 /usr/local/sbin/acer-mode

#
# Strictly limited passwordless sudo authorization.
#
# Eric can run only these exact acer-mode invocations as root.
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
        MESSAGE="Performance + TuneD latency-performance"
        ICON="power-profile-performance"
        ;;
    balanced)
        TITLE="Acer mode changed"
        MESSAGE="Balanced + TuneD balanced"
        ICON="power-profile-balanced"
        ;;
    low-power)
        TITLE="Acer mode changed"
        MESSAGE="Low-power + TuneD powersave"
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
echo "Eric can now open the KDE Application Launcher and search for:"
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
