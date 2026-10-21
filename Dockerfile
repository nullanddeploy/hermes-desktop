# Hermes Desktop — a full Ubuntu desktop that Hermes itself can drive.
# XFCE desktop over VNC/noVNC (port 6080) + Hermes agent with the
# computer_use toolset (cua-driver) enabled, all in one container.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Desktop, VNC server, noVNC web client, accessibility (AT-SPI is required
# by cua-driver on Linux), Python for Hermes, and basic tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-terminal \
    tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    dbus-x11 at-spi2-core x11-xserver-utils \
    fonts-dejavu-core fonts-liberation \
    curl wget git nano sudo ca-certificates gnupg openssh-server \
    python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Google Chrome as the desktop browser (Ubuntu's Firefox is snap-only,
# which does not work inside Docker).
RUN wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update && apt-get install -y /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*

# Non-root user: Chrome refuses to run as root and the desktop is happier
# this way too.
RUN useradd -m -s /bin/bash user \
    && echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user

USER user
WORKDIR /home/user
ENV HOME=/home/user

# Hermes agent in its own virtualenv.
RUN python3 -m venv /home/user/.venv \
    && /home/user/.venv/bin/pip install --no-cache-dir --upgrade pip \
    && /home/user/.venv/bin/pip install --no-cache-dir hermes-agent

ENV PATH="/home/user/.venv/bin:/home/user/.local/bin:${PATH}"

# cua-driver: the binary behind Hermes' computer_use toolset.
# start.sh retries this at boot if the build-time install failed.
RUN hermes computer-use install || true

COPY --chown=user:user start.sh /home/user/start.sh
RUN chmod +x /home/user/start.sh

EXPOSE 6080
CMD ["/home/user/start.sh"]
