# PACER Setup

This directory contains my custom PACER setup for Raptor, raptor-D1-3.syx, consisting of modified presets D1-D3 (these are the only presets contained in the sysex dump). You can load these into the PACER using François Georgy's web-based [PACER Editor][], or any sysex librarian such as [SimpleSysexxer][].

The three presets are based on the A1, D2, and D3 factory presets of the PACER. They provide the following functions within Raptor:

- **D1 (R1PRE):** program changes (PC1-6), these recall presets 1-6 of the arpeggiator
- **D2 (R2MOD):** switches 1-4 are toggles, 5+6 are triggers (momentary switches), assigned as follows:
    - switches 1+2 (down/up) change the octave range (+1 down/up), switch 3, when activated, adds another octave
    - switch 5 (mod) toggles whatever parameter is assigned with the "mod-switch" control (this value can also be changed continuously using EXP2, see below), switch 4 (mod shift) usually reverses polarity of the change (when mod-switch is "sweep", it toggles the "part" setting of the harmonicity sweep subpatch instead)
    - switch 6 triggers "play", turning the arpeggiator on or off
- **D3 (R3ARP):** switches 1-6 select the different arpeggiator modes (random, up, down, up-down, down-up, outside-in); switch 6, when long-pressed (>= 500 ms), toggles "raptor" mode (a very long press >= 1000 ms cancels the operation)
- **EXP1+2:** These refer to the two expression pedals which can be hooked up to the EXP1 and EXP2 sockets on the back of the PACER. They are unchanged from the PACER's factory settings and work in all three presets. In Raptor, EXP1 (CC7) controls the input gain of the velocity tracker, while EXP2 (CC11), like R2MOD switch 5, controls the mod parameter which enables continuous changes of whatever parameter is assigned with the "mod-switch" control.
- **FS1:** This refers to a sustain pedal plugged into the FS1 socket on the back of the PACER. D1-D3 all have FS1 set to CC64 which enables the "hold" function while the pedal is being pressed. Note that many MIDI keyboards also offer this kind of socket and have it assigned to CC64 by default.

**NOTE:** While the above controls can be used from a DAW, they are really designed for live performance. All Raptor parameters also have bindings better suited for MIDI automation, please see the Control section in the toplevel README file for details.

[PACER Editor]: https://studiocode.dev/pacer-editor
[SimpleSysexxer]: http://archive.today/cD4KR
