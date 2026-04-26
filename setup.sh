#!/usr/bin/env bash
set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
fatal()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

print_banner() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║     Project 100 — RHEL 10 Exam Environment       ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
}

if [[ "${EUID}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    fatal "sudo is required. Install sudo and rerun."
  fi
  echo -e "${BOLD}This setup requires administrative privileges.${RESET}"
  echo "Enter your current user password when prompted."
  sudo -v
  exec sudo -i bash "$(readlink -f "$0")" "$@"
fi

print_banner

if [[ ! -f /etc/redhat-release ]]; then
  fatal "This script supports only RHEL hosts."
fi

rhel_major="$(rpm -E %rhel 2>/dev/null || true)"
if [[ "${rhel_major}" != "9" && "${rhel_major}" != "10" ]]; then
  fatal "Unsupported RHEL major version: ${rhel_major:-unknown}. Expected 9 or 10."
fi

IMAGE_DEFAULT="docker.io/acalculus/project100-exam:latest"
CONTAINER_NAME_DEFAULT="project100-exam"
STATE_DIR_DEFAULT="/var/lib/project100-exam"
PERSIST_IMAGE_DEFAULT="localhost/project100-exam:persisted"
ENV_FILE="/etc/project100-exam.env"
# /usr/bin: always on sudo secure_path (unlike /usr/local/bin on many RHEL systems).
ENSURE_SCRIPT="/usr/bin/project100-exam-ensure-container"
EXPIRE_SCRIPT="/usr/bin/project100-exam-expire"
FINALIZE_SCRIPT="/usr/bin/project100-exam-finalize"
FINISH_SCRIPT="/usr/bin/project100-exam-finish-now"
ATTACH_SCRIPT="/usr/bin/project100-exam-attach"
SETUP_MARKER_NAME=".project100-exam-setup-complete"
SERVICE_FILE="/etc/systemd/system/project100-exam.service"
TTL_SERVICE_FILE="/etc/systemd/system/project100-exam-ttl-cleanup.service"
TTL_TIMER_FILE="/etc/systemd/system/project100-exam-ttl.timer"
FINISH_SERVICE_FILE="/etc/systemd/system/project100-exam-finish-now.service"

ensure_host_state_layout() {
  mkdir -p "${STATE_DIR_DEFAULT}" "${STATE_DIR_DEFAULT}/exam-storage" "${STATE_DIR_DEFAULT}/logs"
  chmod 0755 "${STATE_DIR_DEFAULT}" "${STATE_DIR_DEFAULT}/exam-storage" "${STATE_DIR_DEFAULT}/logs"
}



collect_learner_identity() {
  local name email
  ensure_host_state_layout
  while true; do
    read -r -p "Learner full name (required): " name || fatal "Cancelled input."
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    if [[ -n "${name}" ]]; then
      break
    fi
    warn "Name cannot be empty."
  done
  while true; do
    read -r -p "Learner email (required): " email || fatal "Cancelled input."
    email="${email#"${email%%[![:space:]]*}"}"
    email="${email%"${email##*[![:space:]]}"}"
    if [[ -z "${email}" ]]; then
      warn "Email cannot be empty."
      continue
    fi
    if [[ "${email}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      break
    fi
    warn "Invalid email format."
  done
  umask 077
  printf 'NAME=%s\nEMAIL=%s\n' "${name}" "${email}" > "${STATE_DIR_DEFAULT}/learner-identity.txt"
  chmod 600 "${STATE_DIR_DEFAULT}/learner-identity.txt"
  ok "Saved ${STATE_DIR_DEFAULT}/learner-identity.txt"
}

info "[1/9] Installing host prerequisites (podman, curl, chrony, …)…"
dnf install -y podman policycoreutils-python-utils curl chrony
ok "Host packages installed."

info "[2/9] Validating SELinux host mode…"
if ! command -v getenforce >/dev/null 2>&1; then
  fatal "getenforce is unavailable; cannot validate SELinux state."
fi
selinux_mode="$(getenforce || true)"
if [[ "${selinux_mode}" == "Disabled" ]]; then
  fatal "SELinux is Disabled on host. Enable SELinux and reboot before running setup."
fi
if [[ "${selinux_mode}" != "Enforcing" ]]; then
  warn "SELinux mode is ${selinux_mode}. Setting enforcing mode now."
  setenforce 1 || true
fi
ok "SELinux OK (${selinux_mode})."

info "[3/9] Preparing loop module support on host…"
modprobe loop || true
mkdir -p /etc/modules-load.d
cat > /etc/modules-load.d/project100-loop.conf <<'EOF'
loop
EOF
ok "loop module configured."

info "[4/9] Learner identity, time sync, and firewall (HTTPS)…"
ensure_host_state_layout
collect_learner_identity
systemctl enable --now chronyd 2>/dev/null || true
if systemctl is-active --quiet firewalld 2>/dev/null; then
  firewall-cmd --permanent --add-service=https 2>/dev/null || true
  firewall-cmd --reload 2>/dev/null || true
fi

info "[5/9] Writing runtime environment file…"
ensure_host_state_layout
cat > "${ENV_FILE}" <<EOF
BASE_IMAGE=${IMAGE_DEFAULT}
PERSIST_IMAGE=${PERSIST_IMAGE_DEFAULT}
CONTAINER_NAME=${CONTAINER_NAME_DEFAULT}
STATE_DIR=${STATE_DIR_DEFAULT}
TELEGRAM_SECRETS=${STATE_DIR_DEFAULT}/telegram.env
EOF
ok "Wrote ${ENV_FILE}"

info "[6/9] Labeling persistent host storage (SELinux)…"
ensure_host_state_layout
if command -v semanage >/dev/null 2>&1; then
  semanage fcontext -a -t container_file_t "${STATE_DIR_DEFAULT}(/.*)?" 2>/dev/null || true
fi
restorecon -RF "${STATE_DIR_DEFAULT}" || true
ok "State directory ready: ${STATE_DIR_DEFAULT}"

info "[7/9] Installing container ensure and exam lifecycle scripts…"
mkdir -p /etc/systemd/system
cat > "${ENSURE_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /etc/project100-exam.env

if [[ -z "${BASE_IMAGE:-}" || -z "${PERSIST_IMAGE:-}" || -z "${CONTAINER_NAME:-}" || -z "${STATE_DIR:-}" ]]; then
  echo "Missing required env values in /etc/project100-exam.env"
  exit 1
fi

# OCI/Docker: image repository path must be lowercase (e.g. docker.io/user/repo).
BASE_IMAGE="${BASE_IMAGE,,}"

mkdir -p "${STATE_DIR}/exam-storage" "${STATE_DIR}/logs/httpd"

# Require BASE_IMAGE locally: pull from registry (e.g. docker.io) when missing.
if ! /usr/bin/podman image exists "${BASE_IMAGE}"; then
  if ! /usr/bin/podman pull "${BASE_IMAGE}"; then
    echo "project100-exam-ensure-container: ERROR: failed to pull ${BASE_IMAGE}. Push the image to the registry or fix BASE_IMAGE in /etc/project100-exam.env." >&2
    exit 1
  fi
fi
if ! /usr/bin/podman image exists "${BASE_IMAGE}"; then
  echo "project100-exam-ensure-container: ERROR: image ${BASE_IMAGE} not available after pull." >&2
  exit 1
fi

# Host bind replaces /var/lib/exam-storage and /var/log; copy loop images + log dirs from the image when missing.
_need_seed=0
for _img in sdb sdc sdd; do
  if [[ ! -s "${STATE_DIR}/exam-storage/${_img}.img" ]]; then
    _need_seed=1
    break
  fi
done
if [[ "${_need_seed}" -eq 1 ]]; then
  echo "project100-exam-ensure-container: seeding exam-storage/*.img from ${BASE_IMAGE} (bind mount hides image layers)." >&2
  if ! /usr/bin/podman run --rm --pull=never \
    -v "${STATE_DIR}/exam-storage:/out:Z" \
    --user 0:0 \
    --entrypoint /bin/sh "${BASE_IMAGE}" \
    -c 'exec cp -a /var/lib/exam-storage/sdb.img /var/lib/exam-storage/sdc.img /var/lib/exam-storage/sdd.img /out/'; then
    echo "project100-exam-ensure-container: ERROR: failed to copy exam disk images from ${BASE_IMAGE}" >&2
    exit 1
  fi
fi

# Telegram secrets: baked in image at /opt/exam-data/host-provision/telegram.env → host STATE_DIR.
TG_IN_IMAGE="/opt/exam-data/host-provision/telegram.env"
if /usr/bin/podman run --rm --pull=never --entrypoint /bin/cat "${BASE_IMAGE}" "${TG_IN_IMAGE}" \
    > "${STATE_DIR}/telegram.env.tmp" 2>/dev/null && [[ -s "${STATE_DIR}/telegram.env.tmp" ]]; then
  mv -f "${STATE_DIR}/telegram.env.tmp" "${STATE_DIR}/telegram.env"
  chmod 600 "${STATE_DIR}/telegram.env"
else
  rm -f "${STATE_DIR}/telegram.env.tmp"
  echo "project100-exam-ensure-container: warning: could not extract ${TG_IN_IMAGE} from ${BASE_IMAGE}; build with exam-build.env or finalize will fail until telegram.env exists." >&2
fi

# Match `podman run -it`: attach must use a real TTY or console-getty/login breaks (garbled input, stuck prompts).
if /usr/bin/podman container exists "${CONTAINER_NAME}"; then
  if _ins="$(/usr/bin/podman inspect "${CONTAINER_NAME}" --format '{{.Config.Tty}} {{.Config.OpenStdin}}' 2>/dev/null)"; then
    read -r _tty _stdin <<< "${_ins}"
    if [[ "${_tty}" != "true" || "${_stdin}" != "true" ]]; then
      echo "project100-exam-ensure-container: recreating ${CONTAINER_NAME} with --interactive --tty (same as podman run -it; host binds unchanged)." >&2
      /usr/bin/podman rm -f "${CONTAINER_NAME}" || true
    fi
  fi
fi

if ! /usr/bin/podman container exists "${CONTAINER_NAME}"; then
  run_image="${BASE_IMAGE}"
  if /usr/bin/podman image exists "${PERSIST_IMAGE}"; then
    run_image="${PERSIST_IMAGE}"
  fi
  if ! /usr/bin/podman image exists "${run_image}"; then
    echo "project100-exam-ensure-container: ERROR: run image ${run_image} not found locally." >&2
    exit 1
  fi
  PODMAN_EXTRA=()
  # RW bind: libselinux only treats SELinux as enabled if selinuxfs is not ST_RDONLY;
  # RO breaks getenforce/sestatus. Trusted lab only: root in the container can alter host enforcing via selinuxfs.
  if [[ -d /sys/fs/selinux ]]; then
    PODMAN_EXTRA+=( -v /sys/fs/selinux:/sys/fs/selinux )
  fi
  /usr/bin/podman create \
    --interactive \
    --tty \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    --privileged \
    --hostname exam \
    "${PODMAN_EXTRA[@]}" \
    -v "${STATE_DIR}/exam-storage:/var/lib/exam-storage:Z" \
    -v "${STATE_DIR}/logs:/var/log:Z" \
    "${run_image}"
fi

if /usr/bin/podman container exists "${CONTAINER_NAME}"; then
  /usr/bin/podman start "${CONTAINER_NAME}" 2>/dev/null || true
fi
EOF
chmod 0755 "${ENSURE_SCRIPT}"

cat > "${ATTACH_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /etc/project100-exam.env

MARKER="${STATE_DIR}/.project100-exam-setup-complete"
if [[ ! -f "${MARKER}" ]]; then
  echo "project100-exam-attach: missing setup marker ${MARKER}. Run setup.sh successfully first." >&2
  exit 1
fi

/usr/bin/project100-exam-ensure-container
/usr/bin/podman start "${CONTAINER_NAME}" 2>/dev/null || true
exec /usr/bin/podman attach --sig-proxy "${CONTAINER_NAME}"
EOF
chmod 0755 "${ATTACH_SCRIPT}"

cat > "${FINALIZE_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /etc/project100-exam.env

SECRETS="${TELEGRAM_SECRETS:-${STATE_DIR}/telegram.env}"
IDENTITY="${STATE_DIR}/learner-identity.txt"
SCORE_OUT_HOST="${STATE_DIR}/exam-scenario-score.txt"
SCORE_IN_CONTAINER="/root/exam-scenario-score.txt"

if [[ ! -f "${IDENTITY}" ]]; then
  echo "project100-exam-finalize: missing ${IDENTITY}" >&2
  exit 1
fi
if [[ ! -f "${SECRETS}" ]]; then
  echo "project100-exam-finalize: missing ${SECRETS} (Telegram secrets)" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${SECRETS}"
set +a

if [[ -z "${BOT_TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
  echo "project100-exam-finalize: BOT_TOKEN and CHAT_ID must be set in ${SECRETS}" >&2
  exit 1
fi

if ! /usr/bin/podman container exists "${CONTAINER_NAME}"; then
  echo "project100-exam-finalize: container ${CONTAINER_NAME} does not exist" >&2
  if [[ "${FORCE_CLEANUP:-0}" == "1" ]]; then
    exec /usr/bin/project100-exam-expire
  fi
  exit 1
fi

/usr/bin/podman start "${CONTAINER_NAME}" 2>/dev/null || true
sleep 2

if ! /usr/bin/podman exec "${CONTAINER_NAME}" /usr/local/bin/exam-score-scenarios; then
  echo "project100-exam-finalize: exam-score-scenarios failed" >&2
  if [[ "${FORCE_CLEANUP:-0}" == "1" ]]; then
    exec /usr/bin/project100-exam-expire
  fi
  exit 1
fi

/usr/bin/podman cp "${CONTAINER_NAME}:${SCORE_IN_CONTAINER}" "${SCORE_OUT_HOST}"

NAME="" EMAIL=""
while IFS= read -r line || [[ -n "${line}" ]]; do
  case "${line}" in
    NAME=*) NAME="${line#NAME=}" ;;
    EMAIL=*) EMAIL="${line#EMAIL=}" ;;
  esac
done < "${IDENTITY}"

{
  echo "Name: ${NAME}"
  echo "Email: ${EMAIL}"
  echo ""
  cat "${SCORE_OUT_HOST}"
} > /tmp/project100-telegram-body.txt

if [[ "$(wc -c < /tmp/project100-telegram-body.txt)" -gt 3800 ]]; then
  head -c 3800 /tmp/project100-telegram-body.txt > /tmp/project100-telegram-body2.txt
  printf '\n...[truncated]' >> /tmp/project100-telegram-body2.txt
  mv -f /tmp/project100-telegram-body2.txt /tmp/project100-telegram-body.txt
fi

TG_OUT="$(mktemp)"
trap 'rm -f "${TG_OUT}" /tmp/project100-telegram-body.txt' EXIT

if ! curl -fsS --max-time 60 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text@/tmp/project100-telegram-body.txt" -o "${TG_OUT}"; then
  echo "project100-exam-finalize: curl to Telegram failed" >&2
  cat "${TG_OUT}" >&2 || true
  exit 1
fi
if ! grep -q '"ok":true' "${TG_OUT}"; then
  echo "project100-exam-finalize: Telegram API did not return ok:true" >&2
  cat "${TG_OUT}" >&2 || true
  exit 1
fi

trap - EXIT
rm -f "${TG_OUT}" /tmp/project100-telegram-body.txt

exec /usr/bin/project100-exam-expire
EOF
chmod 0755 "${FINALIZE_SCRIPT}"

cat > "${FINISH_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
/usr/bin/systemctl stop project100-exam-ttl.timer 2>/dev/null || true
/usr/bin/systemctl disable project100-exam-ttl.timer 2>/dev/null || true
exec /usr/bin/project100-exam-finalize
EOF
chmod 0755 "${FINISH_SCRIPT}"

cat > "${EXPIRE_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /etc/project100-exam.env

_finish_main="$(/usr/bin/systemctl show project100-exam-finish-now.service -p MainPID --value 2>/dev/null || echo "")"

# Stop and disable managed services/timer first.
/usr/bin/systemctl stop project100-exam.service || true
/usr/bin/systemctl disable project100-exam.service || true
/usr/bin/systemctl stop project100-exam-ttl.timer || true
/usr/bin/systemctl disable project100-exam-ttl.timer || true
# Stopping project100-exam-finish-now while running as its MainPID sends SIGTERM to this process (finalize execs expire).
if [[ ! "${_finish_main}" =~ ^[0-9]+$ || "${_finish_main}" -ne $$ ]]; then
  /usr/bin/systemctl stop project100-exam-finish-now.service || true
fi
/usr/bin/systemctl disable project100-exam-finish-now.service || true

# Tear down container and images.
/usr/bin/podman rm -f "${CONTAINER_NAME}" || true
/usr/bin/podman rmi -f "${PERSIST_IMAGE}" || true
/usr/bin/podman rmi -f "${BASE_IMAGE}" || true

# Remove storage and helper artifacts.
/usr/bin/rm -rf "${STATE_DIR}" || true
/usr/bin/rm -f /etc/project100-exam.env || true
/usr/bin/rm -f /usr/bin/project100-exam-ensure-container || true
/usr/bin/rm -f /usr/bin/project100-exam-finalize || true
/usr/bin/rm -f /usr/bin/project100-exam-finish-now || true
/usr/bin/rm -f /usr/bin/project100-exam-attach || true

# Remove service files and this cleanup script itself.
/usr/bin/rm -f /etc/systemd/system/project100-exam.service || true
/usr/bin/rm -f /etc/systemd/system/project100-exam-ttl-cleanup.service || true
/usr/bin/rm -f /etc/systemd/system/project100-exam-ttl.timer || true
/usr/bin/rm -f /etc/systemd/system/project100-exam-finish-now.service || true
/usr/bin/rm -f /usr/bin/project100-exam-expire || true
/usr/bin/rm -f \
  /usr/local/bin/project100-exam-ensure-container \
  /usr/local/bin/project100-exam-expire \
  /usr/local/bin/project100-exam-finalize \
  /usr/local/bin/project100-exam-finish-now \
  /usr/local/bin/project100-exam-attach \
  2>/dev/null || true

/usr/bin/systemctl daemon-reload || true
/usr/bin/systemctl reset-failed || true
EOF
chmod 0755 "${EXPIRE_SCRIPT}"

# Drop legacy paths (sudo secure_path often excludes /usr/local/bin).
/usr/bin/rm -f \
  /usr/local/bin/project100-exam-ensure-container \
  /usr/local/bin/project100-exam-expire \
  /usr/local/bin/project100-exam-finalize \
  /usr/local/bin/project100-exam-finish-now \
  /usr/local/bin/project100-exam-attach \
  2>/dev/null || true

cat > "${TTL_SERVICE_FILE}" <<'EOF'
[Unit]
Description=Finalize Project100 Exam (score, Telegram, cleanup) after TTL
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/project100-exam-finalize
EOF

cat > "${TTL_TIMER_FILE}" <<'EOF'
[Unit]
Description=Run Project100 Exam TTL finalize at 6 hours

[Timer]
OnActiveSec=6h
Persistent=true
Unit=project100-exam-ttl-cleanup.service

[Install]
WantedBy=timers.target
EOF

cat > "${FINISH_SERVICE_FILE}" <<'EOF'
[Unit]
Description=Submit Project100 exam scores to Telegram and cleanup now
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/project100-exam-finish-now
EOF

info "[8/9] Installing systemd units…"
cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=Project100 Exam Container (ensure image, create/start container)
After=network-online.target chronyd.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
EnvironmentFile=/etc/project100-exam.env
ExecStart=/usr/bin/project100-exam-ensure-container
ExecStop=/bin/bash -lc 'set -a; source /etc/project100-exam.env; set +a; exec /usr/bin/podman stop -t 15 "${CONTAINER_NAME}"'
TimeoutStopSec=70

[Install]
WantedBy=multi-user.target
EOF

info "[9/9] Enabling timer and bootstrapping exam container…"
systemctl daemon-reload
systemctl enable project100-exam.service
systemctl enable project100-exam-ttl.timer
# Schedule TTL first; start exam container last (matches unit After= ordering on boot).
systemctl start project100-exam-ttl.timer || true

if systemctl start project100-exam.service; then
  printf '%s\n%s\n' "Project100 exam host setup completed successfully." "$(date -Is)" > "${STATE_DIR_DEFAULT}/${SETUP_MARKER_NAME}"
  chmod 0644 "${STATE_DIR_DEFAULT}/${SETUP_MARKER_NAME}"
  ok "project100-exam.service started; setup marker written."
else
  warn "project100-exam.service failed to start; setup marker not created."
  warn "Fix registry access or set BASE_IMAGE in ${ENV_FILE} to your pushed image, then: sudo systemctl start project100-exam.service"
fi

echo ""
echo -e "${BOLD}── Next steps ──${RESET}"
ok  "Attach (TTY to init): sudo ${ATTACH_SCRIPT}"
info "Start container only: sudo systemctl start project100-exam.service"
ok  "Finish exam (score + Telegram + cleanup): sudo ${FINISH_SCRIPT}"
info "  or: sudo systemctl start project100-exam-finish-now.service"
info "Status: systemctl status project100-exam.service --no-pager"
info "Container: podman ps -a --filter name=${CONTAINER_NAME_DEFAULT}"

if [[ -z "${SETUP_SKIP_INTERACTIVE:-}" ]] && [[ -t 0 ]]; then
  if [[ -f "${STATE_DIR_DEFAULT}/${SETUP_MARKER_NAME}" ]]; then
    echo ""
    info "Attaching to ${CONTAINER_NAME_DEFAULT} (primary process /sbin/init). See podman-attach(1); container uses --restart unless-stopped."
    exec "${ATTACH_SCRIPT}"
  else
    echo ""
    warn "Skipping attach (setup marker missing). After fixing the service: sudo ${ATTACH_SCRIPT}"
  fi
else
  echo ""
  info "Skipping interactive attach (no TTY or SETUP_SKIP_INTERACTIVE=1). Run: sudo ${ATTACH_SCRIPT}"
fi
