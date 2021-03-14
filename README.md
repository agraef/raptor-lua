# Raptor: The Random Arpeggiator

March 2021  
Albert Gräf <aggraef@gmail.com>  
Dept. of Music-Informatics  
Johannes Gutenberg University (JGU) Mainz, Germany

The raptor6.pd patch implements an experimental arpeggiator program based on the mathematical music theories of the contemporary composer Clarence Barlow. This is already the 6th iteration of this program, now ported to Lua so that it can be run easily with any Pd version. Compared to earlier versions, it also features much cleaner source code and some other noticeable improvements under the hood. We recommend running this patch with [Purr Data][], Jonathan Wilkes' modern Pd flavor, as it has all the required externals including Pd-Lua on board, and the layout of the GUI has been optimized for that version. But the patch should also work fine in "vanilla" [Pd][] if you have the [Pd-Lua][] and [Zexy][] externals installed (a version of Pd-Lua for Lua 5.3 or later is required, you can find this under the given URL). The screenshot below shows the patch running in Purr Data.

<img src="raptor6.png" alt="raptor6" style="zoom: 70%;" />

A few sample presets are included in the presets folder, use the `p` abstractions in the lower right corner of the main patch to switch between these (or create your own). The main patch also has some controls to change meter and tempo, as well as an abundance of other parameters controlling the algorithm in the `panel` subpatch. If you need a whole band of Raptors to accompany you, multiple instances of the main patch can be run in concert in a single Pd instance. Just make sure that you select one of the instances as the time master (`M` toggle in the "time" subpatch) which happens automagically if you press the big green `play` toggle in one of the instances.

Raptor is quite advanced as arpeggiators go, it's really a full-blown algorithmic composition tool, although it offers the usual run-of-the-mill deterministic and random arpeggios as well. But the real magic starts when you turn on `raptor` mode and start playing around with the parameters in the panel. Documentation still needs to be written. The algorithm behind Raptor is briefly sketched out in my [ICMC 2006 paper][] (cf. Section 8), but for the time being you'll also have to dive into the source code and read Barlow's article in the [Ratio book][] if you'd like to get a deeper understanding of how the algorithm works.

Using the patch is easy enough, however. Hook up your MIDI keyboard and synthesizer to Pd's MIDI input and output, respectively, press `play` and just play some chords. Most of the time, I'm using Raptor with a MIDI guitar setup and a [Nektar PACER][] foot pedal, so the patch is somewhat geared towards that use case, but it also works fine with any MIDI keyboard and a free software synth such as [Qsynth][]. Below you'll find some information to get you started.

This project is still work in progress. There's some stuff on the TODO list, such as MIDI clock sync, OSC control, and a looper facility. The included presets also need some work, but hey, you get them for free! ;-) Feel free to modify and use them for whatever purpose. Bug reports and other contributions are welcome, and please do send me links to music produced with Raptor!

## Meter and Tempo

Raptor's note generation process is guided by the chosen meter which determines the pulse strength of each step in the pattern. We employ Barlow's *indispensability* measure to calculate these. Barlow's method requires the meter to be specified in *stratified* form as a list of (prime) subdivisions, such as 3-2-2 (3/4 subdivided into 16th notes), 2-3-2 (6/8 in 16ths), or 2-2-3 (12/16). Raptor also enables you to specify the meter as a simple number of beats, in which case it partitions the number into its prime factors in ascending order, e.g.: 6 = 2-3, 12 = 2-2-3, 10 = 2-5, 14 = 2-7, etc. If this default stratification is not what you want, you can also specify the stratification explicitly as a Pd list such as `3 2`, `2 3 2`, `5 2`, `7 2`, etc.

This purely mathematical way of specifying meters often makes things easier when dealing with complicated rhythms, but it has the disadvantage that the tempo is set in relation to the (anonymous) base pulse implied by the meter instead of some fixed note value, and thus the actual *physical* tempo increases with the number of pulses. E.g., a tempo of 100 bpm in 12 (2-2-3) runs at 200 ms per step, whereas the same tempo in 15 (3-5) has 160 ms per step, which is of course faster. The tempo section of the patch lets you choose the bpm value and displays the corresponding ms value. Sometimes you may want to keep two different meters in sync so that you can easily switch between them or run them in parallel. This is quite easy to do by calculating the ratio between the two meters. E.g., for 12 and 15 we get 15/12 = 5/4, and thus 5/4✕100 = 125 bpm makes 2-2-3 go exactly as fast as 3-5 at 100 bpm.

## Harmonicity

The other central notion in Raptor's note generation process is that of *harmonicity*, which is Barlow's measure for the *consonance* and *dissonance* of intervals. Normally, an arpeggiator sequences exactly the notes you play, over a range of different octaves. Raptor can do that, too, but things get way more interesting when you engage `raptor` mode which selects notes at random based on the *average harmonicities* with respect to the notes you play. To these ends, you specify a range of harmonicities (`hmin`, `hmax`), as well as a corresponding bias (`hmod`) which is used to vary the actual harmonicities with the pulse strengths. Eligible step sizes for the generated pattern (i.e., intervals measured in semitones between the notes in successive steps) can be specified with the `smin` and `smax` parameters, and you can also tell Raptor how many notes to generate in each step with the `nmax` parameter. As with all the other parameters, these values can be modulated according to the current pulse strength using the corresponding bias values (`smod`, `nmod`).

Last but not least, there is the parameter of harmonic *preference* (`pref`) which determines how much harmonious notes are to be preferred in the note selection process. Its value can also be negative which lets you prefer *low* harmonicities in order to produce anti-tonal patterns. As usual, the parameter can be modulated with the corresponding bias value (`prefmod`), so that the preference changes with pulse strength. For instance, this lets you produce patterns with less harmonious notes only on the weak pulses. This parameter can be *very* effective when used with the right choice of `hmin` and `hmax` values.

By all these means, patterns can become a lot more varied, and may contain notes you didn't actually play, as well as chords rather than just single notes in each step. With the right choice of parameters, Raptor can go from plain tonal to a more jazz-like and free feel to completely atonal (or even anti-tonal) in a continuous fashion. Such "harmonicity sweeps" are a hallmark feature of many of Barlow's compositions. To make it easier to employ this kind of effect in live performances, Raptor includes the `harm-sweep` subpatch which lets you trigger a sweep of minimum harmonicity and/or harmonic preference, to get that "Barlow style" and return to tonality at the push of a button.

## Control

All of Raptor's parameters have MIDI bindings, so they can be automatized, e.g., in a DAW. For live performance, the patch contains a control subpatch for the PACER, and I've also included my modified PACER setup in case you want to use it, please check the pacer subfolder for details. But all the various switches and parameters are also accessible through the GUI or the MIDI bindings listed below.

**NOTE:** In the following table, *PC* refers to "program change", *CC* to "control change" messages. Like any MIDI input in Raptor, these are only received on the MIDI input channel (`in` numbox) set in the panel, which can be zero to denote "omni", i.e., receive on all MIDI channels.

The table also lists the range of parameters. For "discrete" controls (0-1 or 0-n switches), the control value is taken as is, and any value greater than the number of alternatives is clamped to the given range. In particular, for 0-1 switches, *any* positive value means "on". For other ("continuous") controls the full 0-127 MIDI range is mapped to the parameter range, and a CC value of 64 denotes the middle of the range (which means zero for parameters with a bipolar range). 0-100 ranges generally denote percentages. Some parameters denote bias values ranging from -100 to +100% which are used for automatic modulation of other parameters according to pulse strengths in the chosen meter. A *positive* bias means that the value of the dependent parameter increases for *stronger* and decreases for *weaker* pulses, and vice versa for a *negative* bias; a *zero* bias means that the parameter does *not* vary with pulse strength at all.

| Control    | Range     | Meaning                                                      |
| ---------- | --------- | ------------------------------------------------------------ |
| PC         | 0..127    | selects preset 1-128                                         |
| CC7        | 0..127    | input gain of the velocity tracker                           |
| CC8        | 0..127    | pan                                                          |
| CC16, CC17 | -64..63   | octave range (down, up)                                      |
| CC18       | -64..63   | transpose                                                    |
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
