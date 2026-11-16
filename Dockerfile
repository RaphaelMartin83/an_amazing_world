FROM debian:trixie-slim

ARG GODOT_VERSION=4.7.2
ENV GODOT_VERSION=${GODOT_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip zip git \
        xvfb xauth libgl1 libxcursor1 libxinerama1 libxi6 libxrandr2 libxkbcommon0 \
        libfontconfig1 libasound2t64 \
        mesa-vulkan-drivers libgl1-mesa-dri libegl1 \
        python3 python3-pil \
    && rm -rf /var/lib/apt/lists/*

# Godot editor/runtime (Linux) + export templates (Windows/Linux exports)
RUN curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /opt \
    && mv /opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && curl -fsSL -o /tmp/tpl.tpz \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && mkdir -p /opt/xdg/godot/export_templates \
    && unzip -q /tmp/tpl.tpz -d /tmp/tpl \
    && mv /tmp/tpl/templates /opt/xdg/godot/export_templates/${GODOT_VERSION}.stable \
    && rm -rf /tmp/godot.zip /tmp/tpl.tpz /tmp/tpl

WORKDIR /project

# Run as any host user: templates live in a world-readable XDG dir, writable state in /tmp
RUN mkdir -p /opt/xdg/godot/app_userdata && chmod -R a+rwX /opt/xdg
ENV XDG_DATA_HOME=/opt/xdg \
    XDG_CONFIG_HOME=/tmp/xdg-config \
    XDG_CACHE_HOME=/tmp/xdg-cache \
    HOME=/tmp
