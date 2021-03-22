# Raptor: The Random Arpeggiator

March 2021  
Albert Gräf <aggraef@gmail.com>  
Dept. of Music-Informatics  
Johannes Gutenberg University (JGU) Mainz, Germany

The raptor6.pd patch implements an experimental arpeggiator program based on the mathematical music theories of the contemporary composer and computer music pioneer Clarence Barlow. This is already the 6th iteration of this program, now ported to Lua so that it can be run easily with any Pd version. Compared to earlier versions, it also features a much cleaner source code and many noticeable improvements, including more robust timing, MIDI clock sync, and a built-in looper. We recommend running this patch with [Purr Data][], Jonathan Wilkes' modern Pd flavor, as it has all the required externals including Pd-Lua on board, and the layout of the GUI has been optimized for that version. But the patch should also work fine in "vanilla" [Pd][] if you have the [Pd-Lua][] and [Zexy][] externals installed (a version of Pd-Lua for Lua 5.3 or later is required, you can find this under the given URL). The screenshot below shows the patch running in Purr Data.

<img src="raptor6.png" alt="raptor6" style="zoom: 67%;" />

Raptor is quite advanced as arpeggiators go, it's really a full-blown algorithmic composition tool, although it offers the usual run-of-the-mill deterministic and random arpeggios as well. But the real magic starts when you turn on `raptor` mode and start playing around with the parameters in the panel. The algorithm behind Raptor is briefly sketched out in my [ICMC 2006 paper][] (cf. Section 8), and you'll find some practical information to get you started below. But if you'd like to get a deeper understanding of how the algorithm actually works, you'll have to dive into the source code and read Barlow's article in the [Ratio book][] for now.

Using the patch is easy enough, however. Hook up your MIDI keyboard and synthesizer to Pd's MIDI input and output, respectively, press the green `play` button and just play some chords. I'm mostly using Raptor with a MIDI guitar and a [Nektar PACER][] foot pedal these days, so the patch is somewhat tailored to that use case, but it also works fine with just a MIDI keyboard and a free software synth such as [Qsynth][].

This project is still work in progress. In particular, the included presets need some work, but hey, you get them for free, so feel free to modify and use them for whatever purpose! ;-) Bug reports and other contributions are welcome. I'm always curious about music made with my programs, so please do send me links to music produced with Raptor!

## Getting Started

When Raptor launches, all parameters are set to factory defaults, which can be found in the `init` subpatch. A few sample presets are included in the presets folder, use the `p` abstractions in the lower right corner of the main patch to switch between these, or create your own. As shipped, the first preset labeled `default` is identical to the factory defaults, so that you can quickly restore some sane defaults if needed. More presets can be found in the `more...` subpatch.

Presets are stored on disk as editable text files in Pd's qlist format (which basically just lists parameter names and their corresponding values). The file name is specified using the second argument of the `p` abstraction, and the third argument indicates the PC (program change) number which can be used to select the preset using MIDI control. The latter can be omitted if selection of a preset by PC is not needed. However, the first argument of the `p` abstraction is mandatory and *must* be `$0`, which tells the abstraction which Raptor instance to operate on.

The main patch has quite a few controls to change meter, tempo, and the other parameters of the algorithm, as well as a few MIDI-related settings (input and output channel, program number) in the `panel` and `harm-sweep` subpatches. The current state of all these parameters is stored in a preset on disk if you hit the `save` button, so that you can recall it later with the `recall` button. The `load` button lets you reload a preset from disk and immediately recall it, which is useful if you edited the preset outside of Raptor in a text editor, and of course all presets are reloaded automatically whenever you launch Raptor.

For live performance, the patch contains a control subpatch for the PACER, and I've also included my modified PACER setup in case you want to use it, please check the pacer subfolder for details. But all the various switches and parameters are also accessible through the GUI or the MIDI bindings listed at the end of this document.

## Meter and Tempo

Raptor's note generation process is guided by the chosen *meter* which determines the pulse strength of each step in the pattern. We employ Barlow's *indispensability* measure to calculate these. Barlow's method requires the meter (or more precisely the number of beats) to be specified in *stratified* form as a list of (prime) subdivisions, such as, e.g., 3-2-2 (3/4 subdivided into 16th notes), 2-3-2 (6/8 in 16ths), or 2-2-3 (12/16). Therefore, if you to specify the meter as a single composite number, Raptor assumes a partition of the number into its prime factors in ascending order, e.g.: 6 = 2-3, 12 = 2-2-3, 15 = 3-5, etc. This is usually in line with musical tradition (at least in the simple cases), but if you want a different stratification, you can also specify it explicitly as a Pd list such as `3 2`, `2 3 2`, `5 3`, etc.

In any case, Raptor suggests a base pulse when you specify a meter. Traditionally, these are powers of 2, so Raptor calculates the base pulse by rounding up the number of beats to the next power of 2 (e.g., 4 becomes 4/4, 6 becomes 6/8, 15 becomes 15/16, etc.). If the suggested default isn't what you want, you can change it manually after setting the number of beats. E.g., to get a 9/8 meter, you'd enter `9` using the big slider or the numbox at the top, then change the default `16` pulse to `8` in the numbox at the bottom of the `meter` subpatch.

*Tempo* may be specified using the traditional quarter beats per minute (bpm) value. The corresponding pulse period in ms is calculated automatically and displayed in the numbox labeled `ms`. You can also enter the period and have the corresponding bpm value calculated instead. Note that the pulse period depends on the base pulse of the meter. E.g., at a tempo of 120 bpm, quarters run at 500 ms per step, 8ths at double speed (250 ms/step), 16ths at quadruple speed (125 ms/step), etc. Seasoned musicians should be well familiar with all this, so let's move on to the closely related topic of *time*. 

## Time

Transport starts rolling as soon as you turn on the big green `play` toggle at the top of the Raptor patch, and stops when turning it off again, *after* the arpeggiator finishes playing the current bar (the beat indicator in the `arp` subpatch changes to red until the arpeggiator really stops; if needed, you can also start and stop transport instantly with the leftmost, unlabeled toggle in the `time` subpatch). Playback usually starts at the beginning of a bar, but you can also have an *anacrusis* (an upbeat) if you enter the pulse offset (counting from zero) into the little numbox in the `time` subpatch. This value can also be negative, to indicate a position relative to the *end* of a bar (e.g., -1 tells Raptor to start on the *last* beat of a bar).

When transport is rolling, Raptor generates pulses according to the current meter and tempo settings, and the arpeggiator creates note output at each pulse from the calculated pulse strengths and the notes that you're currently playing. At any point in time, you can change *any* of the arpeggiator's parameters, including arpeggiation mode, meter and tempo, and (of course) the notes you play, and Raptor will respond immediately by changing the sequenced pattern accordingly.

You can even have a whole band of Raptors accompanying you, by running multiple instances of the main patch in concert in the same Pd instance. In that case, *exactly one* of the instances must be selected as the "time master" which takes care of the transport, as indicated by the `M` toggle in the `time` subpatch. This happens automatically if you press the big green `play` toggle in one of the instances.

Finally, Raptor can also sync to an external time source via MIDI clock messages, in which case that time source takes over Raptor's transport and determines tempo and pulse period. Most DAWs support this, you just need to enable MIDI clock output in the DAW, connect it to any of Pd's MIDI inputs, and make sure that clock sync is enabled in the time master by engaging the `S` toggle in the `time` subpatch (which is on by default using factory settings). As soon as Raptor starts receiving MIDI clocks, the pulse button in the `time` patch turns red, playback starts automatically, and the current tempo and pulse period are displayed in the tempo section. Playback stops as soon as Raptor receives a MIDI stop message, or hasn't received MIDI clocks for a short while (3 seconds in the current implementation, but this value can be changed in the `midiclock` abstraction).

## Harmonicity

The second central notion in Raptor's note generation process is that of *harmonicity*, which is Barlow's measure for the consonance of intervals. Normally, an arpeggiator sequences exactly the notes you play, over a range of different octaves. Raptor can do that, too, but things get way more interesting when you engage `raptor` mode which selects notes at random based on the *average harmonicities* with respect to the current input chord (the notes you play). To these ends, you specify a range of harmonicities (`hmin`, `hmax`), as well as a corresponding bias (`hmod`) which is used to vary the actual harmonicities with the pulse strengths. Eligible step sizes for the generated pattern (i.e., intervals measured in semitones between the notes in successive steps) can be specified with the `smin` and `smax` parameters, and you can also tell Raptor how many notes to generate in each step with the `nmax` parameter. As with all the other note generation parameters, these values can be modulated according to the current pulse strength using the corresponding bias values (`smod`, `nmod`).

Last but not least, there is the parameter of harmonic *preference* (`pref`) which determines how much harmonious notes are to be preferred in the note selection process. Its value can also be negative which lets you prefer *low* harmonicities in order to produce anti-tonal patterns. As usual, the parameter can be modulated with the corresponding bias value (`prefmod`), so that the preference changes with pulse strength (for instance, this lets you produce patterns with less harmonious notes only on the weak pulses). This parameter can be *very* effective when used with the right choice of `hmin` and `hmax` values.

By these means, patterns become a lot more varied, containing notes you didn't actually play, as well as chords rather than just single notes in each step. With the right choice of parameters, Raptor can go from plain tonal to a more jazz-like feel to completely atonal (or even anti-tonal) in a continuous fashion. Such "harmonicity sweeps" are a hallmark feature of many of Barlow's compositions. To employ this kind of effect in live performances, the `harm-sweep` subpatch lets you do sweeps of minimum harmonicity and/or harmonic preference either manually or in a fully automatic fashion. So you can now "go Barlow" on a whim and quickly return to the safe harbor of tonality, or play an entire piece in "Barlow style" if you want!

## Loops

Version 6 of Raptor now finally has an integrated looper facility. There are two related GUI controls, a numbox-toggle pair labeled `loop`, at the bottom of the `panel` subpatch. The numbox tells Raptor the number of bars to record. Engaging the toggle saves whatever you just played to an internal buffer (up to the given number of bars, but the looper will also be happy with less if input runs short) and immediately starts looping it. Disengaging the toggle instantly clears the loop and resumes normal arpeggiator operation. While the loop is playing, note input to the arpeggiator is suspended, so you can use your input controller to play along. Control input works normally, though, so you can also start twiddling the knobs, change presets, etc. Since the looper records the arpeggiator's *output*, not its input, most of the preset options won't have an immediate effect, but output options such as MIDI channel and program and the velocity tracker will work.

Loops are always quantized to whole bars, so you *must* keep playing for at least one bar to have anything recorded. This kind of "launch quantization" should be well familiar to Ableton Live users, although it works a bit differently here. First, there's no overdubbing state; this wouldn't make any sense because the arpeggiator is suspended during loop playback, so there's nothing to record. Second, Raptor's looper always records "after the fact", so no separate button press is needed to explicitly start the recording. The looper is *always* listening, so once transport is rolling *and* you actually start playing, you just push the button *once* to save and loop whatever you just played. This may need some getting used to, but it's the best way to do it given Raptor's probabilistic nature, as you simply can't predict when that killer pattern will come around. On the other hand, it requires you to specify the target loop size beforehand, so some planning ahead is still needed.

You can see at a glance that a loop is playing by looking at the `loop` subpatch. The `save/load` button will have turned red to indicate that there's a loop that can be saved to disk, and the pulse indicator flashes at the beginning of each loop iteration. If you push the button, the file is saved in the preset folder under the name of the preset that is currently selected, with a slot number (0 to 99) from the numbox and the ".loop" extension tacked onto it. (If the file already exists, a backup copy will be created automatically.) The loop can then be reloaded later by pressing the `load/save` button again when no loop is playing. Both the `loop` and `load/save` buttons also have PACER bindings, so they can be operated hands-free.

## The GUI

Before we go into Raptor's MIDI controls, let's have a quick look at some important GUI (graphical user interface) controls in the Raptor patch that you should know about. As indicated below, some of these are saved in the patch itself, so you can just save the patch to change their defaults.

First, in the main patch there's the `mod-switch` control (saved in the patch) which assigns some PACER controls to various different parameters for hands-free operation. Most related controls can be found in the `panel` subpatch; the most prominent of these are the yellow mute toggle (labeled `M`) which mutes the arpeggiator (stops all note output), and the green hold toggle (labeled `H`) which holds all note input in memory, so that the arpeggiator keeps playing the same pattern while this toggle is engaged. These are mostly intended for live control and automation, so they both have MIDI bindings (CC64 and CC67). Of course, you can also operate them in the GUI, but their state is neither saved in the patch nor in presets.

The `mod-switch` control goes into the `control` subpatch which implements most of Raptor's MIDI control logic, including the interface to the PACER. This subpatch has a numbox (labeled `cin`) and a toggle (both saved in the patch) which allow you to set Raptor's control input channel, and to enable or disable control input separately for each Raptor instance. By default, the MIDI channel is set to 0 (omni) and control input is enabled. The control input toggle is mostly for interactive usage, e.g., if you need to control individual instances in a multi-Raptor setup via MIDI. The MIDI channel can be set (and saved) to your liking. E.g., it often makes sense to have all your control inputs, such as the PACER, a fader box, or MIDI automation from your DAW, go into a separate Pd input port, so that normal MIDI input from other devices doesn't accidentally interfere with the control channel. Pd has a set of 16 MIDI channels for each MIDI input, so you can set the control input channel, e.g., to 17 in order to receive control data on channel 1 of the second MIDI input.

Next, in the `time` subpatch there are the time master and MIDI clock sync toggles (labeled `M` and `S`, respectively, both saved in the patch), which we already discussed in the "Time" section. There's another (unlabeled) start/stop toggle (not saved) which enables you to start and stop the sequence manually, and a pulse button to trigger individual pulses in a step-wise fashion, which can be useful for debugging purposes. As discussed in the "Time" section, the pulse button also goes red to indicate MIDI clock sync, in which case you better not mess with it to keep Raptor in sync with the time source. Also, the little anacrusis numbox on the left will set the pulse offset from the beginning of a bar (counting from zero) when playback starts. This is filled in automatically if your DAW sends song position pointer (SPP) messages, but you can also set it manually (whether using MIDI clock sync or not) if you need to start playback on an upbeat.

Last but not least, there's the `arp` subpatch containing the guts of the arpeggiator itself. You can send a `panic` message to the arpeggiator to kill hanging notes, and switch the metronome on and off with the toggle control in the upper-right corner (saved in the patch). A gray slider gives an indication of the pulse strengths, and the gray beat indicator next to it briefly flashes at the beginning of each bar. You'll also notice that this indicator temporarily goes red if you stop the sequence, until the arpeggiator finishes playing the current bar.

In the second row you find the `trace` control (saved in the patch) which changes the amount of time that note-offs are delayed. This produces a kind of "legato" effect, making notes stick around a little longer while you're changing chords. The slider goes from 0 to 600 ms and should be adjusted to your playing style, the default being 300 ms (the button to the right resets to that value); setting it to zero disables tracing. There's also a `gain` control which sets the input gain of the *velocity tracker*, which can be enabled or disabled with the `veltrk` toggle (saved in the patch). The velocity tracker calculates a kind of envelope from the velocities of the notes that you play and adjusts the velocities of output notes generated by the arpeggiator accordingly, so that they follow your performance. The current envelope value is displayed in the number box to the right of the toggle, and can also be changed manually there if needed. Alternatively, the `gain` control, which is bound to the MIDI volume controller (CC7) and also stored in presets, allows you to boost the envelope value on the fly if needed. This is a quick remedy if your MIDI controller produces very low velocities, as some controllers do, or you could also use it as an expression control. But note that the `gain` value is just for amplification, not attenuation; changing the envelope value in the numbox goes both ways.

Finally, hidden away at the bottom of the `arp` subpatch you'll find two additional toggles, `bend` and `touch` (both saved in the patch), which determine whether to pass through pitch bend and aftertouch (a.k.a. channel pressure) messages from MIDI input to output. As shipped, pass-through is enabled for pitch bend and disabled for aftertouch, but you can change this to whatever you like if you open that subpatch.

## Control

Most of Raptor's parameters have MIDI bindings, so they can be automatized, e.g., in a DAW:

| Control    | Range     | Meaning                                                      |
| ---------- | --------- | ------------------------------------------------------------ |
| PC         | 0..127    | selects preset 1-128                                         |
| CC1        | 0..127    | harmonicity sweep (also bound to CC11 in the PACER configuration) |
| CC7        | 0..127    | input gain of the velocity tracker                           |
| CC8        | 0..127    | pan (0 = hard left, 127 = hard right, 64 = center)           |
| CC16, CC17 | -64..63   | octave range (number of octaves down, up, meaningful range is -3..3) |
| CC18       | -64..63   | transpose (input notes are transposed by the given number of semitones) |
| CC19       | 0..5      | mode (0: random, 1: up, 2: down, 3: up-down, 4: down-up, 5: outside-in) |
| CC20       | 0..1      | raptor mode (on/off)                                         |
| CC21, CC22 | 0..127    | minvel, maxvel (range of velocity values)                    |
| CC23       | -100..100 | velmod (velocity bias, modulates velocity)                   |
| CC24, CC25 | 0..100    | pmin, pmax (range of note probabilities)                     |
| CC26       | -100..100 | pmod (note probability bias)                                 |
| CC27, CC28 | 0..100    | hmin, hmax (harmonicity range)                               |
| CC29       | -100..100 | hmod (harmonicity bias)                                      |
| CC30       | -100..100 | pref (harmonic preference)                                   |
| CC31       | -100..100 | prefmod (harmonic preference bias)                           |
| CC64       | 0..1      | hold (keep current chord in memory while "on")               |
| CC67       | 0..1      | mute (suppress note output while "on")                       |
| CC75       | 0..200    | gate (as percentage of pulse length)                         |
| CC76       | -100..100 | gatemod (gate bias)                                          |
| CC77       | -100..100 | swing bias (note delays modulated by pulse strength)         |
| CC78       | 0..127    | meter (number of pulses, always uses normal stratification; e.g., 12 = 2-2-3) |
| CC84, CC85 | -128..127 | smin, smax (min and max step size)                           |
| CC86       | -100..100 | smod (step size bias)                                        |
| CC87       | 0..127    | nmax (maximum chord size a.k.a. number of notes per step)    |
| CC88       | -100..100 | nmod (chord size bias)                                       |
| CC89       | 0..1      | uniq (don't repeat notes in consecutive steps)               |

##### Notes:

- Raptor is controlled using two types of MIDI messages, *PC* (program change) and *CC* (control change). Control input has its own MIDI channel which can be zero to denote "omni" (listen on all channels). This is set in the `control` subpatch and is independent of note input, please check the GUI section for details.
- For "discrete" controls (0-1 switches: hold, mute, raptor mode, and uniq; 0-n switches: mode), the control value is taken as is, and any value greater than the number of alternatives is clamped to the given range. In particular, for the 0-1 switches, *any* positive value means "on". For other ("continuous") controls the full 0-127 MIDI range is mapped to the parameter range given in the table, and a CC value of 64 denotes the middle of the range (which means zero for parameters with a bipolar range, such as the "bias" parameters explained below).
- 0-100 ranges generally denote percentages, which are used for probabilities (pmin, pmax) and harmonicities (hmin, hmax). The gate parameter, which determines how long generated output notes are sustained, is also specified as a percentage of the pulse length, but its range goes from 0% (extreme staccato) to 200% (extreme legato), with 100% (the default) indicating that each note lasts exactly as long as the pulse length. Some parameters (pref, swing, as well as all the "mod" parameters) denote bias values ranging from -100% to +100% which are used for automatic modulation of other parameters according to pulse strengths in the chosen meter. A *positive* bias means that the value of the dependent parameter increases for *stronger* and decreases for *weaker* pulses; conversely, a *negative* bias indicates that the parameter increases for *weaker* and decreases for *stronger* pulses; and a *zero* bias means that the parameter does *not* vary with pulse strength at all.

## Bugs and Limitations

Here are some known issues that might be fixed in future versions (or not), and how to avoid them. Anything else that seems to be missing or not working properly? File a [bug report][], or (better yet) submit a [pull request][]!

##### OSC Support

Obviously, it would be nice to have support for [OSC][] to get around the limited resolution of MIDI CCs. However, OSC often requires a fair amount of messing about just to get application and controller to talk to each other. It's a lot easier to get connected with MIDI gear, the resolution is certainly good enough for most purposes, and it's always possible to use the GUI for fine adjustments. So I wouldn't hold my breath for this.

##### Time Sync

While MIDI sync should just work out of the box if your DAW can spit out a coherent stream of MIDI clocks, pulses may occasionally appear to be "shifted" (out of phase) if the meter settings don't match up, or if your DAW lacks support for song position pointer (SPP) messages and you start playback in the middle of a bar.

There's not really much that can be done about this on the Raptor side, as the limitations are in the protocol (or due to bugs in the DAW). We might add more comprehensive protocols such as MTC or MMC some time, and [Ableton Link][] seems to be the way to go for networked jam sessions. But MIDI clocks are so much simpler and they work with pretty much any music application and recording gear, so they will do for now. Just make sure that you have Raptor's meter (and anacrusis) set correctly, then you should be fine.

##### Looper Features

It goes without saying that Raptor's looper is (by design) quite basic. Its main purpose is to give you a simple way of putting a generated musical phrase on repeat while you have your hands free for soloing, diffusion (knob-twiddling), or recording that beautiful pattern before it vanishes forever. It also allows you to save loops on disk, and those .loop files are just Lua tables, so they can easily be edited in a text editor or processed in Lua. But if you need more features, then I'd recommend combining Raptor with a DAW tailored to live usage, such as Ableton Live or Bitwig Studio, or even just a standard DAW like Ardour or Reaper. In particular, this gives you the ability to record the *input* to the arpeggiator, which makes it much easier to tweak the results later.

That said, some usability improvements might still be in order. There could be more convenient ways to edit saved loops, maybe through MIDI export and import. The velocity tracker levels aren't saved with the loops, so a loop may sound much louder or quieter next time you load it. Fortunately, it's easy to work around this issue by adjusting the tracker level. Some other limitations in the current implementation are that at most 256 steps can be recorded, and quantization is restricted to whole bars. The former probably isn't a big deal in practice and can easily be changed in the source if needed. But the user might certainly want to change the latter to different subdivisions of the meter, which currently isn't possible.



[ICMC 2006 paper]: http://hdl.handle.net/2027/spo.bbp2372.2006.021
[Ratio book]: http://clarlow.org/wp-content/uploads/2016/10/THE-RATIO-BOOK.pdf

[Purr Data]: https://agraef.github.io/purr-data/
[Pd]: http://msp.ucsd.edu/software.html
[Zexy]: https://github.com/iem-projects/pd-zexy
[Pd-Lua]: https://agraef.github.io/pd-lua/
[Qsynth]: https://qsynth.sourceforge.io/
[Nektar PACER]: https://nektartech.com/pacer-midi-daw-footswitch-controller/
[OSC]: https://www.cnmat.berkeley.edu/opensoundcontrol
[Ableton Link]: https://www.ableton.com/link/
[bug report]: https://github.com/agraef/raptor-lua/issues
[pull request]: https://github.com/agraef/raptor-lua/pulls