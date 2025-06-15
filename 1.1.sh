#!/bin/bash

for pid_dir in /proc/[0-9]*; do
    PID=$(basename "$pid_dir")   
    echo "$PID"
done
