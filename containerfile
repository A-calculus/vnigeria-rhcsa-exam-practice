FROM registry.redhat.io/rhel10/rhel-bootc:10.1

LABEL maintainer="Damilola Aderinto <d.aderinto@vnigeria.com>" \
      description="Project 100 practice on RHEL 10."

COPY etc /etc
COPY opt /opt
COPY usr/local/bin /usr/local/bin

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
        management-client \
        cronie \
        openssh-server \
        acl \
        selinux-policy-devel \
        firewalld \
        autofs \
        nfs-utils \
        podman \
        chrony \
        lvm2 \
        dosfstools \
        xfsprogs \
        tuned \
    && dnf clean all

RUN systemctl disable bootc-fetch-apply-updates.timer || true

RUN if [ -f /etc/management-client/.credentials ]; then chmod 600 /etc/management-client/.credentials; fi

# Pre-stage required identities so exam users exist by default.
RUN chmod 0755 /usr/local/bin/* || true

RUN groupadd -f devteam && \
    id kunle >/dev/null 2>&1 || useradd -m -s /sbin/nologin kunle && \
    echo 'kunle:flectrag' | chpasswd


RUN systemctl enable NetworkManager httpd firewalld crond sshd exam-secondary-iface.service management-client.service

RUN firewall-offline-cmd --add-service=http

# --- Scenario 1: Configure network settings ---
# Keep eth0 reserved for container internet connectivity via the host runtime.
# Learners should perform network reconfiguration tasks on exam0.

# --- Scenario 2: Configure default repositories ---
# dnf/repo configuration practice uses the preserved eth0 connectivity path.

# --- Scenario 3: Debug SELinux for web server on port 82 ---
# Port 82 is preconfigured in httpd; SELinux policy is intentionally not pre-adjusted.
# Learners must diagnose and resolve SELinux + service access issues.
RUN printf '%s\n' 'The project 100 Exam is currently Ongoing' > /var/www/html/index.html && \
    chcon -t user_home_t /var/www/html/index.html

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
# A local fallback NFS dataset is pre-staged under /opt/exam-data/autofs.

# --- Scenario 9: Configure file permissions ---
# ACL tooling is available for per-user permissions on /var/tmp/boot.log.

# --- Scenario 10: Configure user account ---
# Learner creates user dan with UID 2002 and sets password.

# --- Scenario 11: Locate files ---
# Learner finds files owned by kunle and copies results to /root/kunle_results.
RUN mkdir -p /opt/exam-data/kunle /root/kunle_results && \
    touch /opt/exam-data/kunle/notes.txt /opt/exam-data/kunle/report.log
RUN /usr/local/bin/seed-kunle-files

# --- Scenario 12: Find string occurrences ---
# Learner extracts lines containing 'ich' from /usr/share/dict/words.

# --- Scenario 13: Create compressed archives ---
# Learner creates tar archives with gzip, bzip2, and xz compression.

# --- Scenario 14: Rootless container as systemd service ---
# Podman is preinstalled; learner creates dan and rootless unit setup.
RUN install -d -m 0755 /opt/exam-data/container && \
    printf '%s\n' 'Small image hint: podman pull quay.io/libpod/alpine:latest' > /opt/exam-data/container/image-hint.txt

# --- Scenario 15: Install service package and manage service ---
# Staged RPM is available in /opt/exam-data/packages for learner-led install/enable/start.


# --- Scenario 16: Create a script to locate files ---
# Script path /usr/local/bin/file_search is left for learner implementation.

# --- Scenario 17: Resize logical volume ---
# LVM tools are installed. Secondary exam disks are prepared as loopback images.
RUN mkdir -p /var/lib/exam-storage && \
    truncate -s 2G /var/lib/exam-storage/sdb.img && \
    truncate -s 2G /var/lib/exam-storage/sdc.img && \
    truncate -s 2G /var/lib/exam-storage/sdd.img

# Attach loopback images on boot and expose stable exam aliases.
# Containers cannot reliably force kernel names /dev/sdb and /dev/sdc.
RUN systemctl enable exam-disk-setup.service

# Pre-stage LVM prerequisites while keeping learner tasks unsolved.
RUN systemctl enable exam-lvm-seed.service

# --- Scenario 18: Add swap partition ---
# Learner can use the prepared loopback images to create swap and fstab entries.

# --- Scenario 19: Create logical volume with vfat mount ---
# dosfstools and lvm2 are available for vfat-on-LV workflow.

# --- Scenario 20: Configure tuned profile ---
RUN systemctl enable tuned

# --- Scenario 21: Collaborative directory with sticky bit ---


# --- Scenario 22: Firewalld service + custom port/service ---
# Learner must add service ftp and port 2121/tcp via firewalld.

CMD ["/sbin/init"]
