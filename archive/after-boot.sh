#!/bin/bash
sudo mount UUID=c607585d-c23c-4a3a-bf3e-5cfa8634d18c ~/m2
sudo mount -o noatime,compress-force=zstd:3 UUID=0a78a96e-2b8d-4ac1-9a84-be69b1b7f52f ~/hdd1
sudo nvidia-smi -pl 280
sudo nvidia-smi -pm 1
imwheel
sudo mount -t tmpfs -o size=12G ramdisk ~/ramdisk
