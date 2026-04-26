# Project 100 — exam practice (RHEL bootc container)

This repository builds and documents a **RHEL 10 bootc-style OCI image** used as a hands-on exam environment. **Candidates** run a host script and attach to a long-lived container; **builders** produce the image and push it to a registry.

---

## 1. Building the RHEL container image

### Base image and build file

The image is defined by [`containerfile`](containerfile). It targets a **RHEL bootc** base (see `RHEL10-image-mode.txt` for the recommended tag and syntax). Building requires a **RHEL (or suitably subscribed) build host** so `dnf` can resolve Red Hat repos.

### Subscription and build arguments

- Copy [`exam-build.env.example`](exam-build.env.example) to **`exam-build.env`** (gitignored) and set real values for scoring/notification build args if you use them.
- Example build from the repo root:

  ```bash
  sudo podman build -t project100-exam:latest -f containerfile . \
    --cap-add=all --security-opt=label=type:container_runtime_t --device /dev/fuse \
    --build-arg-file=exam-build.env
  ```

- Tag the result for your registry (example):

  ```bash
  sudo podman tag project100-exam:latest docker.io/<your-org>/project100-exam:latest
  sudo podman push docker.io/<your-org>/project100-exam:latest
  ```

### Aligning the candidate host with your image

After you publish the image, set **`BASE_IMAGE`** in **`/etc/project100-exam.env`** on exam machines (written or updated when [`setup.sh`](setup.sh) runs) so `podman pull` / create uses the same reference you built and pushed.

---

## 2. Host setup flow (candidate exam environment)

High-level behavior of [`setup.sh`](setup.sh) when run as **root** on a supported RHEL host:

1. **Prerequisites** — Ensures tooling (e.g. Podman), state directories under `/var/lib/project100-exam`, and SELinux labeling as needed.
2. **Identity** — Collects candidate details (name, email, etc.) per your deployment.
3. **Environment** — Writes `/etc/project100-exam.env` (including **`BASE_IMAGE`**).
4. **Systemd** — Installs units for ensure/start/attach, TTL, finalize, and cleanup.
5. **Container** — If **`BASE_IMAGE`** is not local, pulls it; creates the **persistent** exam container (name **`project100-exam`** — not `podman run --rm` for the real exam).
6. **Marker** — On success, creates **`/var/lib/project100-exam/.project100-exam-setup-complete`**.
7. **Attach vs start** — Candidates typically run **`sudo project100-exam-attach`** for an interactive shell inside the container; **`sudo systemctl start project100-exam.service`** can start the container without a TTY.
8. **TTL and finish** — A **~6 hour** timer triggers automated finalize (scoring, notification, teardown). Candidates can finish early with **`sudo project100-exam-finish-now`** or **`sudo systemctl start project100-exam-finish-now.service`**.
9. **Expire / cleanup** — Finalize removes host state and related units; another attempt requires re-running setup (or your operator process).

---

## 3. Other details

### Documentation map

| Audience | Document |
|----------|----------|
| Learners (tasks only) | [`Questions.md`](Questions.md) |
| Instructors / full spec | [`scenario-workbook.md`](scenario-workbook.md) (includes submission examples and operator sections) |
| AI assistants | [`agent.md`](agent.md), [`SKILL.md`](SKILL.md) |

### Scoring and notifications

At finalize, the host runs automated checks against the container state and can send results through a configured channel. **Secrets and tokens** belong in **`exam-build.env`** at build time and in host-extracted runtime config — not committed to the repo. See comments in `containerfile` and `setup.sh`.

### Repository layout (sketch)

- **`containerfile`** — Image build
- **`etc/`**, **`opt/exam-data/`**, **`usr/local/bin/`** — Files copied into the image
- **`setup.sh`** — Host installer / orchestration for candidates
- **`RHEL9-image-mode.txt`**, **`RHEL10-image-mode.txt`** — bootc reference for agents and humans

### Troubleshooting

- **SELinux on the host** — If exercises that read enforcement disagree with the host, ensure the exam container is run with **read-write** bind of `/sys/fs/selinux` where your setup expects it (see `SKILL.md` / `agent.md`).
- **Registry pull failures** — Check `BASE_IMAGE`, network, and registry credentials; `project100-exam-ensure-container` fails the pull if the image is unreachable.
- **Lost container or scoring** — Using **`podman run --rm`** for the real exam drops the writable layer and breaks finalize; use **`project100-exam-attach`** after **`setup.sh`**.

### Deprecated paths (external links)

If older docs linked **`debugger-agent.md`** or **`debugger-SKILL.md`**, use the unified **[`agent.md`](agent.md)** and **[`SKILL.md`](SKILL.md)** instead. The **`sample-questions/`** directory is no longer used; scenarios live in **`scenario-workbook.md`**.
