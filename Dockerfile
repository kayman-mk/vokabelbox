FROM debian:bookworm-slim AS client-build

ARG FLUTTER_VERSION=3.50.1
ARG FLUTTER_SHA256=4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git libglu1-mesa unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

ENV PATH="/opt/flutter/bin:${PATH}"

# The SDK archive is owned by root and Flutter invokes Git during startup.
RUN git config --global --add safe.directory /opt/flutter

WORKDIR /src/client
COPY client/pubspec.yaml client/pubspec.lock ./
RUN flutter config --no-analytics --enable-web \
    && flutter pub get
COPY client/ ./
RUN flutter build web --release --dart-define=API_BASE_URL=/api/v1

FROM nginx:1.29-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=client-build /src/client/build/web /usr/share/nginx/html
