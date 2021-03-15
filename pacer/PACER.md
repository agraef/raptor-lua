# PACER Setup

**NOTE:** While the controls discussed below can be used from a DAW, they are really designed for live performance. All Raptor parameters also have bindings better suited for MIDI automation, please see the Control section in the toplevel README file for details.

The Nektar PACER makes for a great hands-free controller for live performances with Raptor, especially if you're playing MIDI guitar. This directory contains my custom PACER setup for Raptor, raptor-D1-3.syx, consisting of modified presets D1-D3 (these are the only presets contained in the sysex dump). You can load these into the PACER using François Georgy's web-based [PACER Editor][], or any sysex librarian such as [SimpleSysexxer][].

The three presets are based on the A1, D2, and D3 factory presets of the PACER. They provide the following functions within Raptor:

- **D1 (R1PRE):** program changes (PC1-6), these recall presets 1-6 of the arpeggiator
- **D2 (R2MOD):** switches 1-4 are toggles, 5+6 are triggers (momentary switches), assigned as follows:
    - switches 1+2 (down/up) change the octave range (+1 down/up), switch 3, when activated, adds another octave
    - switch 4 (mod shift) and switch 5 (mod) together control whatever parameter is assigned with the "mod-switch" control in the main patch, see below for details
    - switch 6 triggers "play", turning the arpeggiator on or off; unlike the other switches, this trigger is always received by the part which currently acts as the time master (i.e., the Raptor patch which has the "M" toggle engaged; note that only one part can be the time master at any one time)
- **D3 (R3ARP):** switches 1-6 select the different arpeggiator modes (random, up, down, up-down, down-up, outside-in); switch 6, when long-pressed (>= 500 ms), toggles "raptor" mode (a very long press >= 1000 ms cancels the operation)
- **EXP1+2:** These refer to the two expression pedals which can be hooked up to the EXP1 and EXP2 sockets on the back of the PACER. They are unchanged from the PACER's factory settings and work in all three presets. In Raptor, EXP1 (CC7) controls the input gain of the velocity tracker, while EXP2 (CC11), like R2MOD switch 5, controls the mod parameter which enables continuous changes of whatever parameter is assigned with the "mod-switch" control. The latter control is also bound to CC1 (the modulation wheel), so that you can also modify the parameter on your MIDI keyboard.
- **FS1:** This refers to a sustain pedal plugged into the FS1 socket on the back of the PACER. D1-D3 all have FS1 set to CC64 which enables the "hold" function while the pedal is being pressed. Note that many MIDI keyboards also offer this kind of socket and have it assigned to CC64 by default, so that you can also invoke the "hold" function from your keyboard if needed.

**The mod-switch control:** In preset D2 (R2MOD), switch 5 (mod) toggles whatever parameter is assigned using the "mod-switch" control in the main patch. Switch 4 (mod shift), when engaged, reverses the polarity of the change (going down if the unshifted control goes up, and vice versa). The selected parameter can also be changed continuously using EXP2 in any preset, see above. Currently the available mod-switch options are velmod, pmod, gate, gatemod, and swing, which change the corresponding panel value, as well as sweep and autosweep which control the harmonicity sweep effect in the `harm-sweep` subpatch. The sweep option lets you change harmonicity and/or preference manually using switch 5 or the EXP2 pedal, going down by default and up if switch 4 (mod shift) is engaged. The autosweep option simply triggers the automatic sweep as configured in the `harm-sweep` subpatch (here it doesn't make a difference whether switch 4 is engaged or not).

**Keyboard operation:** As already mentioned above, the "mod" and "hold" parameters have bindings to the standard CC1 (modulation wheel) and CC64 (sustain pedal) controls, which will give you at least some minimal controls for live performance on your MIDI keyboard when using Raptor without the PACER.

[PACER Editor]: https://studiocode.dev/pacer-editor
[SimpleSysexxer]: http://archive.today/cD4KR
