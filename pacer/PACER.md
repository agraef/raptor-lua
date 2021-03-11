# PACER Setup

This directory contains my custom PACER setup for Raptor, raptor-D1-3.syx, consisting of modified presets D1-D3 (these are the only presets contained in the sysex dump). You can load these into the PACER using François Georgy's web-based [PACER Editor][], or any sysex librarian such as [SimpleSysexxer][].

The three presets are based on the A1, D2, and D3 factory presets of the PACER. They provide the following functions within Raptor:

- **D1 (R1PRE):** program changes (PC1-6), these recall presets 1-6 of the arpeggiator
- **D2 (R2MOD):** switches 1-4 are toggles, 5+6 are triggers (momentary switches), assigned as follows:
  - switches 1+2 (down/up) change the octave range (+1 down/up), switch 3, when activated, adds another octave
  - switch 5 (mod) toggles whatever parameter is assigned with the "mod-switch" control, switch 4 (mod shift) usually reverses polarity of the change (when mod-switch is "sweep", it toggles the "part" setting instead)
  - switch 6 triggers "play", turning the arpeggiator on or off
- **D3 (R3ARP):** momentary switches 1-6, these select the different arpeggiator modes (random, up, down, up-down, down-up, outside-in); switch 6, when long-pressed (>= 500 ms), toggles "raptor" mode (a very long press >= 1000 ms cancels the operation)
- In addition, D1-D3 all have FS1 set to CC64 which momentarily triggers the "hold" function. Just hook up your sustain pedal to the FS1 socket on the back of the PACER to enable this function.

[PACER Editor]: https://studiocode.dev/pacer-editor
[SimpleSysexxer]: http://archive.today/cD4KR