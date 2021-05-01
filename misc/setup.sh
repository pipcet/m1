#!/bin/bash
cd /Volumes/$VOLNAME
rm -f $MACHO
while ! curl http://$HOST:$PORT/$MACHO > $MACHO || test $(cat $MACHO | wc -c) -lt 81920; do
    sleep 1;
done
(echo y; echo $USER) | kmutil configure-boot -c $MACHO -v /Volumes/Macintosh\ HD && reboot
