#!/bin/sh

clang \
    -framework Foundation \
    -framework CoreBluetooth \
    -o bluetooth_app \
    -fobjc-arc \
    -x objective-c \
    bluetooth_example.m
