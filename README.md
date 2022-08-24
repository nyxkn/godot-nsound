# NSound

Sound system for adaptive music and game audio in Godot.

The goal is to implement an adaptive music system which provides most of the features expected out of typical game audio middleware.

Most of the ideas are taken from FMOD, Wwise, and Elias Studio 3.

The system is designed to be very flexible. Songs can be composed in many different ways,
offering the possibility of combining horizontal sequencing and vertical layering as desired.

Custom logic can also be provided through scripting.

> *** Project is still work in progress, but it's nearing a stable api ***
>
> Documentation will be improved soon.

## Installation

Place the `nsound` directory into your project's `addons` folder.

## Quickstart

Create a new instance of "MusicSystem" in your scene.

Inside `MusicSystem`, instance a `Song` node and therein one or more `Section` nodes.

Here's a hypothetical configuration of your song and all the nodes:

```
MusicSystem
    Song
        Section1
            MultiTrack --- tracks 1,2,3 played randomly
                1 AudioTrack
                2 AudioTrack
                3 SegmentsTrack --- tracks 1,2 played sequentially
                    1 AudioTrack
                    2 AudioTrack
                    
        Section2
            LevelsTrack --- tracks 1,2 played depending on current level value
                1 AudioTrack for Level1
                2 AudioTrack for Level2
                
        Stingers --- manually triggered one-shot stingers
            1 Stinger AudioTrack
            2 Stinger AudioTrack
```

Fill in both the Song and Section properties in the inspector as required.
You'll want to at least set a `BPM` value, a `Beats per bar` value,
and the Section's length in number of `Bars`.

Values set in `Section` will override values set in `Song`.

Finally, inside `Section`, you can add any combination of containers.

You should be able to combine containers in whatever way you like.

In each container you'll add your audio files (wrapped in `AudioTrack` nodes).

From code you will then call MusicSystem.load_song() and play() to start the track.

## Nodes and components explained

### Song

Your outermost container. It contains everything that makes up a whole song.

Here you can set the BPM and Beats Per Bar values of your song.

It will contain any number of `Sections`.

You can also extend this Song node in order to provide custom scripting.
This allows you to implement pretty much any logic you want.

### Section

A loopable section of the song with a predefined length in bars.

`Bars` is a required value and defines how long the section is, in number of bars.

A section can be used for vertical layering or horizontal sequencing.

In vertical layering, the section keeps looping indefinitely and tracks are added/removed on each loop.
This is achieved through the use of either a `MultiTrack` or a `Levels` container.

In horizontal sequencing, you can simply hop between sections through the `Transitions` system.

### AudioTrack

The most atomic component of the system.

It contains a single AudioStreamPlayer loaded with your audiofile.

Place these inside any of the `Containers`.

A tool is provided for automatically wrapping audio files into AudioTracks.

### Containers

These are the nodes that contain the actual `Audiotracks`.

Each container provides a different behaviour for how the tracks should be played.

#### MultiTrack container

This contains a playlist of tracks. Each loop, one track will be selected for playing,
depending on the multitrack mode: random, shuffle, sequential.

#### Levels container

This contains a list of tracks, each assigned a level number.

The global `level` value will determine which of the tracks will play.

This is how Elias Studio 3 works.

#### Segments container

This contains a sequence of tracks that will be played sequentially.

For each track you can specify the beat at which it will play.

Particularly useful to make up a loop-length track out of smaller segments,
e.g. creating a track out of percussion one-shots.

#### Stingers container

This is a simple container in which to place all your stinger tracks.

Stingers can be used in `Transitions` or triggered manually.

This is placed under `Song`, not under `Section`.

### Transition

Transitions define the logic for how to move between sections.

Some of the things that you can define:

- new `level` value once transitioned
- custom stinger track to play during the transition
- starting from a custom beat of the new section
- optionally crossfade between the sections

### Scripting

Coming soon.

## Example

Coming soon.

## Documentation

Coming soon.

## Credits

Inspired by [Godot Mixing Desk](https://github.com/kyzfrintin/Godot-Mixing-Desk).

## License

This project is licensed under the terms of the [MIT license](https://spdx.org/licenses/MIT.html).
