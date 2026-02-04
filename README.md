# Cinematic
A mod for [Minetest](https://www.minetest.net/).

Use chat commands to control your camera when recording in-game videos with aerial views, time lapse, movie-style scenes. The mod runs server-side and controls calling player position and look direction, so using client-side movement will obviously cause disruption.

Camera motions and position controls are placed under `/cc` (cinematic camera). Waypoint paths use `/wp`. Running the commands requires `fly` privilege (they don't make sense without it anyway).

# Camera motions

## 360
```
/cc 360 [r=<radius>] [dir=<l|left|r|right>] [v=<velocity>] [fov=<field of view>]
```
Move the camera around a center point while keeping the focus on the center.

Parameters:
* `r` or `radius` - distance to the center point in the look direction of the player.
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Field of View multiplier to create fish eye effect or  zoom on an object.

## Tilt
```
/cc tilt [v=<velocity>] [dir=<u|up|d|down>] [fov=<field of view>]
```
Rotate the camera vertically, like looking up or down.

Parameters:
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Field of View multiplier to create fish eye effect or  zoom on an object.
## Pan
```
/cc pan [v=<velocity>] [dir=<l|left|r|right>] [fov=<field of view>]
```
Rotate the camera horizontally, like looking to the left or right.

Parameters:
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Field of View multiplier to create fish eye effect or  zoom on an object.
## Truck
```
/cc truck [v=<velocity>] [dir=<l|left|r|right>] [fov=<field of view>]
```
Move the camera sideways without changing the angles, like it is on a truck

Parameters:
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Field of View multiplier to create fish eye effect or  zoom on an object.
## Dolly
```
/cc truck [v=<velocity>] [dir=<f|forward|in|b|back|backwards|out>] [fov=<field of view>]
```
Move the camera forward or backwards in the look direction. You can rotate the camera in motion to set the desired look angles.

Parameters:
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Field of View multiplier to create fish eye effect or  zoom on an object.
## Pedestal
```
/cc pedestal [v=<velocity>] [dir=<u|up|d|down>] [fov=<field of view>]
```
Move the camera vertically. You can rotate the camera in motion to set the desired look angles.

Parameters:
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Field of View multiplier to create fish eye effect or  zoom on an object.
## Zoom
```
/cc zoom [v=<velocity>] [dir=<in|out>] [fov=<field of view>]
```
Gradually zoom on an object or out into panorama view.

Parameters:
* `dir` or `direction` - direction of the camera motion.
* `v` or `speed` - speed multiplier.
* `fov` - Initial Field of View multiplier.
# Camera control
```
/cc stop
```
Stop the camera motion
```
/cc revert
```
Stop and return to initial position.
# Waypoint control
The waypoint system stores per-player paths (waypoints) that persist across rejoining and server restarts. Playlists are saved in mod storage and can be shared between players on the same server. Waypoint commands have moved from `/cc` to `/wp`.

Waypoints capture both position and camera orientation. When a waypoint path starts, the player is moved to the first waypoint and oriented to its look direction before the motion begins.

`stop` waypoints use easing (smooth in/out). `flow` waypoints keep continuous motion (linear interpolation) when passing through a waypoint.
```
/wp add [stop|flow]
```
Save the current position and look direction as a waypoint. `stop` (default) eases in/out at this waypoint. `flow` keeps continuous motion. `flow` also accepts `fluent`, `continuous`, or `go`.
```
/wp clear
```
Clear all stored waypoints for the player.
```
/wp start [name] [speed=<speed>]
```
Start a waypoint path. If `name` is provided, it uses the saved playlist; otherwise it uses the current player waypoints. `speed` (or `v`) is the movement speed in nodes per second (default 4; values <= 0 fall back to 4).
```
/wp cancel
```
Stop the current waypoint motion immediately.
```
/wp playlist save <name>
```
Save the current player waypoints as a named playlist in mod storage. Fails if there are no waypoints.
```
/wp playlist start <name> [speed=<speed>]
```
Start a saved playlist by name. `speed` (or `v`) is the movement speed in nodes per second (default 4; values <= 0 fall back to 4).
```
/wp playlist remove <name>
```
Delete a saved playlist by name.
```
/wp playlist list
```
List saved playlists.
# Position control
Manage the list of camera positions stored in the player's metadata. The list survives rejoining and server restarts.
```
/cc pos save [name]
```
Save the current position and look direction, with an optional name (will be saved in `default` slot if no name provided)
```
/cc pos restore [name]
```
Return to the saved position, either `default` or a named one.
```
/cc pos clear [name]
```
Remove a saved position.
```
/cc pos list
```
Get a list of saved positions.

# Copyright
Copyright (c) 2021 Dmitry Kostenko.
Code License: GNU AGPL v3.0
