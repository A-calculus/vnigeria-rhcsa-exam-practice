FROM registry.redhat.io/rhel10/rhel-bootc:10.1
# Build hint:
# sudo podman build -t project100-exam:latest -f containerfile . --cap-add=all --security-opt=label=type:container_runtime_t --device /dev/fuse --build-arg-file=exam-build.env
# Copy exam-build.env.example -> exam-build.env (gitignored) and set BOT_TOKEN / CHAT_ID.
# Note: SELinux enforcing in image requires host SELinux not to be Disabled.

LABEL maintainer="Damilola Aderinto <d.aderinto@vnigeria.com>" \
      description="Project 100 practice on RHEL 10.1-beta"

ARG BOT_TOKEN=
ARG CHAT_ID=

COPY etc /etc
COPY opt /opt
COPY usr/local/bin /usr/local/bin

RUN install -d -m 0755 /opt/exam-data/host-provision && \
    umask 077 && printf 'BOT_TOKEN=%s\nCHAT_ID=%s\n' "${BOT_TOKEN}" "${CHAT_ID}" \
      > /opt/exam-data/host-provision/telegram.env && \
    chmod 600 /opt/exam-data/host-provision/telegram.env

RUN dnf install -y httpd vim \
        NetworkManager \
        iproute \
        hostname \
        shadow-utils \
        findutils \
        plocate \
        words \
        tar \
        gzip \
        bzip2 \
        xz \
        policycoreutils-python-utils \
        policycoreutils \
        libselinux-utils \
        selinux-policy-targeted \
        cronie \
        openssh-server \
        acl \
        selinux-policy-devel \
        firewalld \
        autofs \
        nfs-utils \
        podman \
        fuse-overlayfs \
        chrony \
        sudo \
        lvm2 \
        parted \
        dosfstools \
        xfsprogs \
        tuned \
    && dnf clean all

RUN systemctl disable bootc-fetch-apply-updates.timer bootc-publish-rhsm-facts.service autofs || true
# RUN systemctl mask nfs-server.service nfs-mountd.service nfs-idmapd.service nfsdcld.service proc-fs-nfsd.mount var-lib-nfs-rpc_pipefs.mount || true
RUN printf '%s\n' exam > /etc/hostname
# RUN systemctl mask proc-sys-fs-binfmt_misc.automount sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount var-lib-nfs-rpc_pipefs.mount proc-fs-nfsd.mount || true

# Pre-stage required identities so exam users exist by default.
RUN chmod 0755 /usr/local/bin/* || true

RUN groupadd -f devteam && \
    mkdir -p /var/spool/mail && \
    id kunle >/dev/null 2>&1 || useradd -m -s /sbin/nologin kunle && \
    echo 'kunle:flectrag' | chpasswd
RUN id student >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash student
RUN echo 'student:student' | chpasswd


RUN systemctl enable NetworkManager httpd firewalld crond sshd exam-secondary-iface.service exam-scenario3-broken-state.service exam-hostname.service exam-disk-setup.service exam-lvm-seed.service exam-block-sync.path management-client.service tuned

RUN firewall-offline-cmd --add-service=http

# --- Scenario 1: Configure network settings ---
# Keep eth0 reserved for container internet connectivity via the host runtime.
# Learners should perform network reconfiguration tasks on exam0.

# --- Scenario 2: Configure default repositories ---
# dnf/repo configuration practice uses the preserved eth0 connectivity path.

# Journal: volatile storage avoids shutdown umount failures when /var/log is bind-mounted
# (see etc/systemd/journald.conf.d/99-exam-volatile-journal.conf).

# --- Scenario 3: Debug SELinux for web server on port 82 ---
# Port 82 is preconfigured in httpd; SELinux policy is intentionally not pre-adjusted.
# Learners must diagnose and resolve SELinux + service access issues.

# --- Scenario 4: Create users, groups, and memberships ---
# Ensure account-management tooling is present (groupadd, useradd, chpasswd).

# --- Scenario 5: Configure a cron job ---
# Cron daemon is enabled; learner creates the minute-based job for user ayo.

# --- Scenario 6: Create collaborative directory ---
# Learner configures /home/book/materials ownership, mode, and setgid behavior.

# --- Scenario 7: Configure SSH password authentication ---
# sshd is available and enabled; learner enforces password-only auth.

# --- Scenario 8: Configure autofs ---
# Autofs and NFS utilities are available; learner supplies maps and verifies mounts.
# A local NFS export dataset is pre-staged under /opt/exam-data/autofs.

# --- Scenario 9: Configure file permissions ---
# ACL tooling is available for per-user permissions on /var/tmp/boot.log.

# --- Scenario 10: Configure user account ---
# Learner creates user dan with UID 2002 and sets password.

# --- Scenario 11: Locate files ---
# Learner finds files owned by kunle and copies results to /root/kunle_results.
RUN mkdir -p /opt/exam-data/kunle && \
    touch /opt/exam-data/kunle/notes.txt /opt/exam-data/kunle/report.log
RUN /usr/local/bin/seed-kunle-files

# --- Scenario 12: Find string occurrences ---
# Learner extracts lines containing 'ich' from /usr/share/dict/words.

# --- Scenario 13: Create compressed archives ---
# Learner creates tar archives with gzip, bzip2, and xz compression.

# --- Scenario 14: Rootless container as systemd service ---
# Podman is preinstalled; learner creates dan and rootless unit setup.
RUN install -d -m 0755 /opt/exam-data/container && \
    printf '%s\n' \
      'Pull: podman pull quay.io/libpod/alpine:latest' \
      'Stay running (no TTY): podman run -d --name practice quay.io/libpod/alpine:latest sleep infinity' \
      'Interactive: podman run -it --rm quay.io/libpod/alpine:latest sh' \
      > /opt/exam-data/container/image-hint.txt
RUN grep -q '^dan:' /etc/subuid || echo 'dan:100000:65536' >> /etc/subuid
RUN grep -q '^dan:' /etc/subgid || echo 'dan:100000:65536' >> /etc/subgid
RUN touch /etc/management-client/.run_next_boot

# --- Scenario 15: Install service package and manage service ---
# Staged RPM is available in /opt/exam-data/packages for learner-led install/enable/start.


# --- Scenario 16: Create a script to locate files ---
# Script path /usr/local/bin/file_search is left for learner implementation.

# --- Scenario 17: Resize logical volume ---
# LVM tools are installed. Secondary exam disks are loopback image files (fixed 2GiB each).
# Fully allocate with dd (not sparse truncate) so backing files consume real space and match a fixed disk size.
RUN mkdir -p /var/lib/exam-storage && \
    dd if=/dev/zero of=/var/lib/exam-storage/sdb.img bs=4M count=512 status=none conv=fsync && \
    dd if=/dev/zero of=/var/lib/exam-storage/sdc.img bs=4M count=512 status=none conv=fsync && \
    dd if=/dev/zero of=/var/lib/exam-storage/sdd.img bs=4M count=512 status=none conv=fsync

# Attach loopback images on boot and expose stable exam aliases.
# Containers cannot reliably force kernel names /dev/sdb and /dev/sdc.

# --- Scenario 18: Add swap partition ---
# Learner can use the prepared loopback images to create swap and fstab entries.

# --- Scenario 19: Create logical volume with vfat mount ---
# dosfstools and lvm2 are available for vfat-on-LV workflow.

# --- Scenario 20: Configure tuned profile ---
# --- Scenario 21: Collaborative directory with sticky bit ---


# --- Scenario 22: Firewalld service + custom port/service ---
# Learner must add service ftp and port 2121/tcp via firewalld.

CMD ["/sbin/init"]
