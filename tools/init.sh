#!/usr/bin/env bash
# Initial environment setup. Adds the current user to the docker group and
# prints the next steps. Idempotent.

set -e

# Docker group — needed so `docker` commands work without sudo. Takes effect
# on the next login or after `newgrp docker`.
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    echo "Added $USER to docker group — log out and back in (or 'newgrp docker')."
fi

echo
echo "Next steps:"
echo "  ./tool docker-build           # build all dev images (one-time, ~10 min)"
echo "  ./tool build                  # build linux/debug (the default)"
echo "  ./tool test                   # run tests against the last build"
echo "  ./tool package --target linux # produce AppImage + .deb"
echo
