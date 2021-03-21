# PACER Setup

**NOTE:** While the controls discussed below can be used from a DAW, they are really designed for live performance. All Raptor parameters also have bindings better suited for MIDI automation, please see the Control section in the toplevel README file for details.

<img src="https://nektartech.com/wp-content/uploads/2018/12/pacer_rear_connections.png" style="zoom:75%;" />

The [Nektar PACER][] makes for a great hands-free controller for live performances with Raptor, especially if you're playing MIDI guitar. This directory contains my custom PACER setup for Raptor, raptor-D1-3.syx, consisting of modified presets D1-D3 (these are the only presets contained in the sysex dump). You can load these into the PACER using François Georgy's web-based [PACER Editor][], or any sysex librarian such as [SimpleSysexxer][].

The three presets are based on the A1 and D2 factory presets of the PACER, but have quite a few modifications (and different names). They provide the following functions within Raptor (the actual CCs are mostly subject to change and thus not listed here; you can find them in Raptor's `control` subpatch if needed):

- **D1 (R1PRE):** program changes (PC1-6), these recall presets 1-6 in the patch (i.e., the `p` abstractions that have 1-6 in their 3rd argument; preset file names are given as the 2nd argument) 
- **D2 (R2MOD):** modulation control, switches 1-4 are toggles, 5+6 are triggers (momentary switches), assigned as follows:
    - switches 1+2 (down/up) adjust the octave range (each step goes one octave down/up, up to -3/+3 octaves, then cycling back to 0 octaves)
    - switch 3 cycles through the available "mod-switch" assignments, while switches 4 (mod shift) and 5 (mod) change whatever parameter is assigned to that control, see below for details
    - switch 6 triggers "play", turning the arpeggiator on or off; unlike the other switches, this trigger is always received by the Raptor instance which currently acts as the time master (i.e., the instance which has the "M" toggle engaged in its `time` subpatch)
- **D3 (R3ARP):** special functions for arpeggiator control, switch 1 is a toggle, the rest are triggers:
    - switch 1 toggles raptor mode
    - switches 2 and 3 cycle through the different arpeggiator modes (random, up, down, up-down, down-up, outside-in), switch 2 switches to the next, switch 3 to the previous arp mode
    - switch 4 triggers the looper in the panel, switch 5 the looper's load/save function in the `looper` subpatch, please check the description of Raptor's looper in the toplevel README for details
    - switch 6, like in D2 (R2MOD), triggers "play"
- **EXP1+2:** These refer to the two expression pedals which can be hooked up to the EXP1 and EXP2 sockets on the back of the PACER. They are unchanged from the PACER's factory settings and work in all three presets. In Raptor, EXP1 (CC7) controls the input gain of the velocity tracker, while EXP2 (CC11), like R2MOD switch 5, controls the mod parameter and enables continuous changes of whatever parameter is assigned with the "mod-switch" control. The latter control is also bound to CC1 (the modulation wheel), so that you can also modify the parameter on your MIDI keyboard.
- **FS1+2:** These refer to foot switches such as a sustain pedal plugged into the FS1 and FS2 sockets on the back of the PACER. D1-D3 all have FS1 and FS2 set to CC64 and CC67 which are bound to the "hold" and "mute" functions of the arpeggiator, respectively. Note that many MIDI keyboards also have a socket for CC64 at least, so that you can also invoke the "hold" function from your keyboard if needed.

**The mod-switch control:** In preset D2 (R2MOD), switch 5 (mod) toggles whatever parameter is assigned using the "mod-switch" control in the main patch. Switch 4 (mod shift), when engaged, reverses the polarity of the change (going down if the unshifted control goes up, and vice versa). The selected parameter can also be changed continuously using EXP2 in any preset, see above. You can also cycle through the available mod-switch options with switch 3. At present these are:

- "off", which completely disables the mod-switch control (this is sometimes useful when running multiple Raptor instances in concert)
- "velmod", "pmod", "gate", "gatemod", and "swing", which change the corresponding parameter in the `panel` subpatch
- "sweep" and "autosweep", which control the harmonicity sweep effect in the `harm-sweep` subpatch

The "sweep" option lets you change harmonicity and/or preference manually using switch 5 or the EXP2 pedal, going up or down depending on whether switch 4 (mod shift) is engaged or not. The "autosweep" option simply triggers the automatic sweep as configured in the `harm-sweep` subpatch (here it doesn't make a difference whether switch 4 is engaged or not).

**Keyboard operation:** As already mentioned above, the "mod-switch" parameters and the "hold" switch have bindings to the standard CC1 (modulation wheel) and CC64 (sustain pedal) controls, which will give you at least some minimal controls for live performance on your MIDI keyboard when using Raptor without the PACER.

[Nektar PACER]: https://nektartech.com/pacer-midi-daw-footswitch-controller/
[PACER Editor]: https://studiocode.dev/pacer-editor
[SimpleSysexxer]: http://archive.today/cD4KR
