#!/bin/sh

PI='music@organellem.local'

scp ble.lua $PI:/tmp/

ssh -T $PI <<'EOF'
    sudo luajit /tmp/ble.lua
EOF
