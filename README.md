

# Raptor: The Random Arpeggiator

March 2021  
Albert Gräf <aggraef@gmail.com>  
Dept. of Music-Informatics  
Johannes Gutenberg University (JGU) Mainz, Germany

The raptor6.pd patch implements an experimental arpeggiator program based on the mathematical music theories of the contemporary composer Clarence Barlow. This is already the 6th iteration of this program, now ported to Lua so that it can be run easily with any Pd version. Compared to earlier versions, it also features much cleaner source code and some other noticeable improvements under the hood. We recommend running this patch with [Purr Data][], Jonathan Wilkes' modern Pd flavor, as it has all the required externals including Pd-Lua on board, and the layout of the GUI has been optimized for that version. But the patch should also work fine in "vanilla" [Pd][] if you have the [Pd-Lua][] and [Zexy][] externals installed (a version of Pd-Lua for Lua 5.3 or later is required, you can find this under the given URL). The screenshot below shows the patch running in Purr Data.

<img src="raptor6.png" alt="raptor6" style="zoom: 67%;" />

Raptor is quite advanced as arpeggiators go, it's really a full-blown algorithmic composition tool, although it offers the usual run-of-the-mill deterministic and random arpeggios as well. But the real magic starts when you turn on `raptor` mode and start playing around with the parameters in the panel. The algorithm behind Raptor is briefly sketched out in my [ICMC 2006 paper][] (cf. Section 8), and you'll find some practical information to get you started below. But if you'd like to get a deeper understanding of how the algorithm actually works, you'll have to dive into the source code and read Barlow's article in the [Ratio book][] for now.

Using the patch is easy enough, however. Hook up your MIDI keyboard and synthesizer to Pd's MIDI input and output, respectively, press `play` and just play some chords. I'm mostly using Raptor with a MIDI guitar and a [Nektar PACER][] foot pedal, so the patch is somewhat geared towards that use case, but it also works fine with any MIDI keyboard and a free software synth such as [Qsynth][].

This project is still work in progress. There's some stuff on the TODO list, such as MIDI clock sync, OSC control, and a looper facility. The included presets also need some work, but hey, you get them for free! ;-) Feel free to modify and use them for whatever purpose. Bug reports and other contributions are welcome, and please do send me links to music produced with Raptor!

## Usage

When Raptor launches, all parameters are set to factory defaults, which can be found in the `init` subpatch. A few sample presets are included in the presets folder, use the `p` abstractions in the lower right corner of the main patch to switch between these, or create your own. (As shipped, the first preset labeled `default` is identical to the factory defaults, so that you can quickly return to some sane defaults if needed.)

Presets are stored on disk as editable text files in Pd's qlist format (which basically just lists parameter names and their corresponding values), and the file name is specified using the second argument of the `p` abstraction. The main patch has quite a few controls to change meter, tempo, and the other parameters of the algorithm, as well as a few MIDI-related settings (input and output channel, program number) in the `panel` and `harm-sweep` subpatches. The current state of all these parameters is stored in a preset on disk if you hit the `save` button, so that you can recall it later with the `recall` button. The `load` button lets you reload a preset from disk and immediately recall it, which is useful if you edit the preset outside of Raptor in a text editor, but of course all presets are also reloaded automatically when launching Raptor.

You can also have a whole band of Raptors accompanying you, by running multiple instances of the main patch in concert in the same Pd instance. Just make sure that you select one of the instances as the time master (`M` toggle in the `time` subpatch), which happens automatically if you press the big green `play` toggle in one of the instances.

Talking about controls, most of them have MIDI bindings (see the "Control" section below) and are also recorded in presets, but there are a few global GUI controls that you should know about. As indicated below, some of these are saved in the Pd patch, so you can just set the controls as you prefer, and save the patch to change their defaults.

First, in the `time` subpatch there is the time master (`M`) toggle (saved in the patch) that we already discussed. But there's also a second (unlabeled) start/stop toggle (not saved) which enables you to start and stop the sequence manually, and a button (a Pd "bang" control) to trigger individual pulses in a step-wise fashion, which can be useful for debugging purposes.

Second, there's the `arp` subpatch containing the guts of the arpeggiator itself. You can send a `panic` message to the arpeggiator to kill hanging notes, and switch the metronome on and off with the toggle control (saved in the patch) in the upper-right corner. A gray slider gives an indication of the pulse strengths (which are also used for the metronome), and the gray bang control besides it briefly flashes on the first (and strongest) pulse of each bar. You'll notice that the bang control also temporarily goes red if you stop the sequence with the `play` control, while the arpeggiator still finishes the current bar. (If needed, you can also stop the sequence immediately using the start/stop toggle in the `time` subpatch.)

In the second row you find the following controls:

- `trace` (saved in the patch) changes the amount of time note-offs are delayed. This produces a kind of "legato" effect, making notes stick around a little longer while you're changing chords. The slider goes from 0 to 600 ms, the default being 300 (the button to the right of the slider resets the control to that value). I find this useful, but your mileage may vary, so you can just disable it by setting its value to 0.

- `gain` controls the input gain of the *velocity tracker* which can be enabled or disabled with the `veltrk` toggle (saved in the patch). The velocity tracker calculates a kind of envelope from the velocities of the notes that you play and adjusts the velocities of generated output notes accordingly, so that they follow your performance. The current value is displayed in the number box to the right of the toggle, and the `gain` control allows you to boost that value if needed. This is a quick remedy if your MIDI controller produces very low velocities, as some controllers do, or you can use it as an expression control. The `gain` control is bound to the MIDI volume controller (CC7) and also stored in presets, rather than being saved in the patch.

Moreover, hidden away at the bottom of the `arp` subpatch you'll find two additional toggles, `bend` and `touch` (both saved in the patch), which determine whether to pass through pitch bend and aftertouch (a.k.a. channel pressure) messages from MIDI input to output. As shipped, pass-through is enabled for pitch bend and disabled for aftertouch, which is the setting that I prefer, but you can change them to whatever you like if you open that subpatch.

## Meter and Tempo

Raptor's note generation process is guided by the chosen *meter* which determines the pulse strength of each step in the pattern. We employ Barlow's *indispensability* measure to calculate these. Barlow's method requires the meter to be specified in *stratified* form as a list of (prime) subdivisions, such as 3-2-2 (3/4 subdivided into 16th notes), 2-3-2 (6/8 in 16ths), or 2-2-3 (12/16). Raptor also enables you to specify the meter as a single composite number of base pulses, in which case it partitions the number into its prime factors in ascending order, e.g.: 6 = 2-3, 12 = 2-2-3, 15 = 3-5, etc. This is usually in line with musical tradition (at least in the simple cases), but if you want a different stratification, you can also specify it explicitly as a Pd list such as `3 2`, `2 3 2`, `5 3`, etc.

*Tempo* may be specified using the traditional quarter beats per minute (bpm) value. Thus the actual pulse frequency depends on the number of base pulses in the meter. E.g., assuming a tempo of 120 bpm, a 4 = 2-2 (a.k.a. common time) meter runs at 500 ms per step, an 8 = 2-2-2 meter at double speed (250 ms/step), 12 = 2-2-3 at triple speed (167 ms/step), you get the idea. This way of denoting tempo is very familiar to musicians, but makes it harder to line up the pulses of incommensurable meters. As a remedy, Raptor lets you specify tempo using *either* bpm *or* ms/step and calculates the other, so that you can use whatever method is most convenient. E.g., consider 12 (2-2-3) and 15 (3-5) at a tempo of 100 bpm which run at 200 ms/step and 160 ms/step, respectively. Now, setting 2-2-3 to the same 160 ms value gives you a tempo of 125 bpm (as you'd expect, since 100 * 15/12 = 100 * 5/4 = 125), which makes both pulse sequences line up perfectly.

## Harmonicity

The other central notion in Raptor's note generation process is that of *harmonicity*, which is Barlow's measure for the consonance of intervals. Normally, an arpeggiator sequences exactly the notes you play, over a range of different octaves. Raptor can do that, too, but things get way more interesting when you engage `raptor` mode which selects notes at random based on the *average harmonicities* with respect to the current input chord (the notes you play). To these ends, you specify a range of harmonicities (`hmin`, `hmax`), as well as a corresponding bias (`hmod`) which is used to vary the actual harmonicities with the pulse strengths. Eligible step sizes for the generated pattern (i.e., intervals measured in semitones between the notes in successive steps) can be specified with the `smin` and `smax` parameters, and you can also tell Raptor how many notes to generate in each step with the `nmax` parameter. As with all the other note generation parameters, these values can be modulated according to the current pulse strength using the corresponding bias values (`smod`, `nmod`).

Last but not least, there is the parameter of harmonic *preference* (`pref`) which determines how much harmonious notes are to be preferred in the note selection process. Its value can also be negative which lets you prefer *low* harmonicities in order to produce anti-tonal patterns. As usual, the parameter can be modulated with the corresponding bias value (`prefmod`), so that the preference changes with pulse strength (for instance, this lets you produce patterns with less harmonious notes only on the weak pulses). This parameter can be *very* effective when used with the right choice of `hmin` and `hmax` values.

By these means, patterns become a lot more varied, containing notes you didn't actually play, as well as chords rather than just single notes in each step. With the right choice of parameters, Raptor can go from plain tonal to more jazz-like to completely atonal (or even anti-tonal) in a continuous fashion. Such "harmonicity sweeps" are a hallmark feature of many of Barlow's compositions. To employ this kind of effect in live performances, the `harm-sweep` subpatch lets you do sweeps of minimum harmonicity and/or harmonic preference either manually or in a fully automatic fashion. So you can now "go Barlow" on a whim and quickly return to the safe harbor of tonality, or play an entire piece in "Barlow style" if you want!

## Control

Most of Raptor's parameters have MIDI bindings, so they can be automatized, e.g., in a DAW. For live performance, the patch contains a control subpatch for the PACER, and I've also included my modified PACER setup in case you want to use it, please check the pacer subfolder for details. But all the various switches and parameters are also accessible through the GUI or the MIDI bindings listed below.

**NOTES:**

- In the following table, *PC* refers to "program change", *CC* to "control change" messages. Like any MIDI input in Raptor, these are only received on the MIDI input channel (`in` numbox) set in the panel, which can be zero to denote "omni", i.e., receive on all MIDI channels.
- The table also lists the range of parameters. For "discrete" controls (0-n switches: mode, raptor mode, hold, and uniq), the control value is taken as is, and any value greater than the number of alternatives is clamped to the given range. In particular, for 0-1 switches (raptor mode, hold, and uniq), *any* positive value means "on".
- For other ("continuous") controls the full 0-127 MIDI range is mapped to the parameter range, and a CC value of 64 denotes the middle of the range (which means zero for parameters with a bipolar range, such as the "bias" parameters explained below).
- 0-100 ranges generally denote percentages, which are used for probabilities (pmin, pmax) and harmonicities (hmin, hmax). The gate parameter, which determines how long generated output notes are sustained, is also specified as a percentage of the pulse length, but its range goes from 0% (extreme staccato) to 200% (extreme legato), with 100% (the default) indicating that each note lasts exactly as long as the pulse length.
- Some parameters (pref, swing, as well as all the "mod" parameters) denote bias values ranging from -100% to +100% which are used for automatic modulation of other parameters according to pulse strengths in the chosen meter. A *positive* bias means that the value of the dependent parameter increases for *stronger* and decreases for *weaker* pulses; conversely, a *negative* bias indicates that the parameter increases for *weaker* and decreases for *stronger* pulses; and a *zero* bias means that the parameter does *not* vary with pulse strength at all.

| Control    | Range     | Meaning                                                      |
| ---------- | --------- | ------------------------------------------------------------ |
| PC         | 0..127    | selects preset 1-128                                         |
| CC1        | 0..127    | harmonicity sweep (also bound to CC11 in the PACER configuration) |
| CC7        | 0..127    | input gain of the velocity tracker                           |
| CC8        | 0..127    | pan (0 = hard left, 127 = hard right, 64 = center)           |
| CC16, CC17 | -64..63   | octave range (number of octaves down, up)                    |
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
| CC75       | 0..200    | gate (as percentage of pulse length)                         |
| CC76       | -100..100 | gatemod (gate bias)                                          |
| CC77       | -100..100 | swing bias (note delays modulated by pulse strength)         |
| CC78       | 0..127    | meter (number of pulses, always uses normal stratification; e.g., 12 = 2-2-3) |
| CC84, CC85 | -128..127 | smin, smax (min and max step size)                           |
| CC86       | -100..100 | smod (step size bias)                                        |
| CC87       | 0..127    | nmax (maximum chord size a.k.a. number of notes per step)    |
| CC88       | -100..100 | nmod (chord size bias)                                       |
| CC89       | 0..1      | uniq (don't repeat notes in consecutive steps)               |

[ICMC 2006 paper]: http://hdl.handle.net/2027/spo.bbp2372.2006.021
[Ratio book]: http://clarlow.org/wp-content/uploads/2016/10/THE-RATIO-BOOK.pdf

[Purr Data]: https://agraef.github.io/purr-data/
[Pd]: http://msp.ucsd.edu/software.html
[Zexy]: https://github.com/iem-projects/pd-zexy
[Pd-Lua]: https://agraef.github.io/pd-lua/
[Qsynth]: https://qsynth.sourceforge.io/
[Nektar PACER]: https://nektartech.com/pacer-midi-daw-footswitch-controller/
