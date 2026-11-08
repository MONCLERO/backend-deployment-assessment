# syntax=docker/dockerfile:1

# -- Stage 1: build -- #
FROM golang:1.25-alpine AS build

WORKDIR /src

# Download dependencies first so this layer is cached until go.mod/go.sum change
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Static binary: no C libraries needed, so it runs in a very small final image
RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" -o /mtd/app ./cmd/api


# -- Stage 2: runtime -- #
FROM alpine:3.20

# Non-root user with no home directory and no login shell
RUN addgroup -S app && adduser -S -G app -H -s /sbin/nologin app

WORKDIR /app

# Compiled binary & .env template copied from the build stage
COPY --from=build --chown=app:app /mtd/app ./much-to-do
COPY --from=build --chown=app:app /src/.env.example .env

USER app

EXPOSE 8080

# Uses BusyBox wget (already in alpine) to call the /health endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -qO /dev/null "http://127.0.0.1:8080/health" || exit 1

ENTRYPOINT ["./much-to-do"]
