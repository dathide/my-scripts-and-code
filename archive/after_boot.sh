#!/bin/bash
sudo nvidia-smi -pl 280
sudo mount -o ssd,noatime,compress-force=zstd:4,discard=async,subvol=subvol1 UUID=951c4330-a12e-40d2-b2bf-9eb1c09aa99f $HOME/m2a
sudo mount -o ssd,noatime,compress-force=zstd:4,discard=async,subvol=subvol1 UUID=d59d8cd9-3815-4f2b-9482-a88e95b8198b $HOME/m2b
sudo mount --mkdir UUID=01DAE04F8A433730 $HOME/win
