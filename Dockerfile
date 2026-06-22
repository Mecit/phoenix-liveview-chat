ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.3.3
ARG DEBIAN_VERSION=trixie-20260406-slim

# Use the exact, pinned Hex.pm image as our single environment
FROM docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}

# Install essential system dependencies for local development
# - build-essential: For compiling C-based Elixir libraries (like SQLite)
# - inotify-tools: Required by Phoenix for live-reloading code in the browser
# - sqlite3: Allows you to inspect your dev database from the container command line
RUN apt-get update && apt-get install -y \
  build-essential \
  inotify-tools \
  sqlite3 \
  git \
  && rm -rf /var/lib/apt/lists/*

# Install Hex package manager and Rebar globally inside the container
RUN mix local.hex --force && \
    mix local.rebar --force

# Set the working directory
WORKDIR /app

# We intentionally do NOT copy any application files here.
# Your docker-compose.yml file will mount your local directory as a volume,
# ensuring that changes you make in VS Code instantly trigger Phoenix live-reload.