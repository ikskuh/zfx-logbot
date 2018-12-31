#!/bin/bash

echo "running zfxlogger.lua in endless loop."
while true; do
	lua zfxlogger.lua
	git pull
	sleep 2
done
