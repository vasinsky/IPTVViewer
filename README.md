Application for MuOS tested on AW Banana (RG35xx H)

The application can work with both remote m3u lists and local ones, watch channels and listen to radio online

The application does not check the validity of the lists (if necessary, you can use online services or collect your own valid and verified list)

The list of remote lists is saved in .iptv-viewer/assets/data/iptvlists.txt
The list of local lists is stored in .iptv-viewer/assets/data/iptvlists

There are several examples for use (I have not checked all channels for functionality, )

Switching between online and offline modes only when viewing the list of names (switching is not available in the list of channel lists) - the "select" button


Save control for the MuOS MPV player (it is used for broadcasts)

I tried to process all possible server response errors, but it is very difficult to catch MPV errors - so if you do not see the video for a long time and do not receive an error - accept it - you will not be able to open the channel

Application logs in the standard log.txt and in assets/data/applog.txt (the log is cleared when the application is launched)

MPV player logs in assets/data/mpv.txt (the log is overwritten)

In Config.lua there is an option to disable logs, store history and with bookmarks

The application records the history of viewing channels in /assets/data/iptvlists/HISTORY.m3u - the file is available when viewing local lists - do not delete it

The application can save a channel you like to bookmarks - the information is in /assets/data/iptvlists/BOOKMARKS.m3u - the "U" button

Unfortunately, I was not able to eliminate the artifacts after closing the MPV video stream - so when you close the player, you will see an animation of the strip on the screen - which cleans up these artifacts (you can force this animation with the left stick)

Navigation through the list of names and the list of channels, for convenience is tied to the DPAD

Up and down - this is vertical listing (works in both directions)
Left and right - this is horizontal - page listing (works in both directions)

```
up = up
down = down
left = left
right = right

select = space #change mode online/offline

left_analog_up = c #clear artefacts mpv
left_analog_down = c #clear artefacts mpv

a = enter
b = x  # back/close mpv
y = z # add to bookmarks

#mpv controls

start = p            # pause
x = m            # mute sound
l1 = 3            # bright less
l2 = 1            # contrast less
r1 = 4            # bright more
r2 = 2            # contrast more
right_analog_up = *            # volume increase
right_analog_up = add_shift
right_analog_down = /        # volume decrease
right_analog_left = [        # speed down 10%
right_analog_right = ]        # speed up 10%
```
