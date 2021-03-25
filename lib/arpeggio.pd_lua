-- Pd external to compute rhythmic arpeggios using Barlow's indispensability
-- method from the Ratio book (Feedback Papers, Cologne, 2001)

-- Author: Albert Gräf <aggraef@gmail.com>, Dept. of Music-Informatics,
-- Johannes Gutenberg University (JGU) of Mainz, Germany, please check
-- https://agraef.github.io/ for a list of my software.

-- Copyright (c) 2021 by Albert Gräf <aggraef@gmail.com>

-- Distributed under the GPLv3+, please check the accompanying COPYING file
-- for details.

local arpeggio = pd.Class:new():register("arpeggio")

-- The object takes the (stratified) meter as (optional) creation argument.
-- The default meter is 4, indicating common time. Meters can be specified as
-- singleton positive integers or lists of integers and are used to compute
-- pulse weights using Barlow indispensabilities. The arguments are in fact
-- exactly the same as in meter.pd_lua (which is included here and can be run
-- alongside the arpeggiator), so please check the comments at the beginning
-- of that source file for details. (The subdivision option -n is currently
-- unsupported, since the arpeggiator object doesn't use it.)

-- The 1st inlet, when receiving a bang, outputs the next note-vel pair in the
-- pattern and advances the current pulse index. This is typically driven by a
-- metro object. It also outputs the current pulse weight (Barlow
-- indispensability) and total number of pulses on the 2nd and 3rd outlet,
-- respectively. This data may be used, e.g., to recalculate note length and
-- metro period according to a given tempo setting, or to feed a drumkit or
-- metronome click. NOTE: The 2nd and 3rd outlet are output on *every* pulse,
-- even if no chord is currently playing.

-- The 1st inlet also accepts a note-vel pair to indicate note-ons and -offs
-- which determine the note input of the arpeggiator. It then updates the
-- internal chord memory and pattern accordingly. It also accepts various
-- other messages to change internal state variables of the arpeggiator which
-- can be used to control the pattern creation and playback process (see below
-- for details).

-- The 2nd inlet takes a stratified meter as input and changes the meter being
-- used by the arpeggiator on the fly.

-- kikito's inspect, cf. https://github.com/kikito/inspect.lua
local inspect = require 'inspect'

function arpeggio:initialize(_, atoms)
   -- 1st inlet takes bang for next pulse and note-vel pairs
   -- 2nd inlet takes stratified meter
   self.inlets = 2
   -- 1st outlet outputs note-vel pairs from the arpeggiator
   -- 2nd outlet outputs the note weight (Barlow indispensability)
   -- 3rd outlet outputs total number of pulses
   self.outlets = 3
   -- debugging (bitmask): 1 = pattern, 2 = input, 4 = output
   self.debug = 0
   -- internal state variables
   self.idx = 0
   self.chord = {}
   self.pattern = {}
   self.hold = nil
   self.down, self.up, self.mode = -1, 1, 0
   self.minvel, self.maxvel, self.velmod = 60, 120, 1
   self.pmin, self.pmax, self.pmod = 0.3, 1, 0
   self.gate, self.gatemod = 1, 0
   -- velocity tracker
   self.veltracker, self.minavg, self.maxavg = 1, nil, nil
   -- this isn't really a "gain" control any more, it's more like a dry/wet
   -- mix (1 = dry, 0 = wet) between set values (minvel, maxvel) and the
   -- calculated envelope (minavg, maxavg)
   self.gain = 1
   -- smoothing filter, time in pulses (3 works for me, YMMV)
   local t = 3
    -- filter coefficient
   self.g = math.exp(-1/t)
   -- looper
   self.loopstate = 0
   self.loopsize = 0
   self.loopidx = 0
   self.loop = {}
   -- Raptor params, reasonable defaults
   self.nmax, self.nmod = 1, 0
   self.hmin, self.hmax, self.hmod = 0, 1, 0
   self.smin, self.smax, self.smod = 1, 7, 0
   self.uniq = 1
   self.pref, self.prefmod = 1, 0
   self.pitchtracker = 0
   self.pitchlo, self.pitchhi = 0, 0
   -- Barlow meter, cf. barlow.pd_lua
   -- XXXTODO: We only do integer pulses currently, so the subdivisions
   -- parameter self.n is currently disabled. Maybe we can find some good use
   -- for it in the future, e.g., for ratchets?
   self.n = 0
   --[[
   self.n = 7 -- subdivisions, seems to work reasonably well up to 7-toles
   if atoms[1] == "-n" then
      self.n = type(atoms[2]) == "number" and atoms[2]+0.0 or self.n
      -- the number of subdivisions must be a positive integer
      if self.n ~= math.floor(self.n) then
	 pd.post("meter: error: number of subdivisions must be integer")
	 return false
      elseif self.n < 1 then
	 pd.post("meter: error: number of subdivisions must positive")
	 return false
      end
      table.remove(atoms, 1)
      table.remove(atoms, 1)
   end
   --]]
   if #atoms == 0 then
      atoms = {4} -- default meter (common time)
   end
   -- initialize the indispensability tables and reset the beat counter
   self.indisp = {}
   self:prepare_meter(atoms)
   return true
end

-- output the number of pulses on the 3rd outlet once we're up and running
function arpeggio:postinitialize()
   self:outlet(3, "float", {self.beats})
end

-- Barlow indispensability meter computation, cf. barlow.pd_lua. This takes a
-- zero-based beat number, optionally with a phase in the fractional part to
-- indicate a sub-pulse below the beat level. We then compute the closest
-- matching subdivision and compute the corresponding pulse weight, using the
-- precomputed indispensability tables. The returned result is a pair w,n
-- denoting the Barlow indispensability weight of the pulse in the range
-- 0..n-1, where n denotes the total number of beats (number of beats in the
-- current meter times the current subdivision).

local barlow = require 'barlow'
-- list helpers
local tabcat, reverse, cycle, map, seq = barlow.tableconcat, barlow.reverse, barlow.cycle, barlow.map, barlow.seq
-- Barlow indispensabilities and friends
local factor, indisp, subdiv = barlow.factor, barlow.indisp, barlow.subdiv
-- Barlow harmonicities and friends
local mod_value, rand_notes = barlow.mod_value, barlow.rand_notes

function arpeggio:meter(b)
   if b < 0 then
      self:error("meter: beat index must be nonnegative")
      return
   end
   local beat, f = math.modf(b)
   -- take the beat index modulo the total number of beats
   beat = beat % self.beats
   if self.n > 0 then
      -- compute the closest subdivision for the given fractional phase
      local p, q = subdiv(self.n, f)
      if self.last_q then
	 local x = self.last_q / q
	 if math.floor(x) == x then
	    -- If the current best match divides the previous one, stick to
	    -- it, in order to prevent the algorithm from quickly changing
	    -- back to the root meter at each base pulse. XXFIXME: This may
	    -- stick around indefinitely until the meter changes. Maybe we'd
	    -- rather want to reset this automatically after some time (such
	    -- as a complete bar without non-zero phases)?
	    p, q = x*p, x*q
	 end
      end
      self.last_q = q
      -- The overall zero-based pulse index is beat*q + p. We add 1 to
      -- that to get a 1-based index into the indispensabilities table.
      local w = self.indisp[q][beat*q+p+1]
      return w, self.beats*q
   else
      -- no subdivisions, just return the indispensability and number of beats
      -- as is
      local w = self.indisp[1][beat+1]
      return w, self.beats
   end
end

function arpeggio:numarg(x)
   if type(x) == "table" then
      x = x[1]
   end
   if type(x) == "number" then
      return x
   else
      self:error("arpeggio: expected integer, got " .. tostring(x))
   end
end

function arpeggio:intarg(x)
   if type(x) == "table" then
      x = x[1]
   end
   if type(x) == "number" then
      return math.floor(x)
   else
      self:error("arpeggio: expected integer, got " .. tostring(x))
   end
end

-- the looper

function arpeggio:loop_clear()
   -- reset the looper
   self.loopstate = 0
   self.loopidx = 0
   self.loop = {}
end

function arpeggio:loop_set()
   -- set the loop and start playing it
   local n, m = #self.loop, self.loopsize
   local b, p, q = self.beats, self.loopidx, self.idx
   -- NOTE: Use Ableton-style launch quantization here. We quantize start and
   -- end of the loop, as well as m = the target loop size to whole bars, to
   -- account for rhythmic inaccuracies. Otherwise it's just much too easy to
   -- miss bar boundaries when recording a loop.
   m = math.ceil(m/b)*b -- rounding up
   -- beginning of last complete bar in cyclic buffer
   local k = (p-q-b) % 256
   if n <= 0 or m <= 0 or m > 256 or k >= n then
      -- We haven't recorded enough steps for a bar yet, or the target size is
      -- 0, bail out with an empty loop.
      self.loop = {}
      self.loopidx = 0
      self.loopstate = 1
      pd.post(string.format("loop: got %d steps, need %d/%d.", p>=n and math.max(0, p-q) or q==0 and n or math.max(0, n-b), b, m))
      return
   end
   -- At this point we have at least 1 bar, starting at k+1, that we can grab;
   -- try extending the loop until we hit the target size.
   local l = b
   while l < m do
      if k >= b then
	 k = k-b
      elseif p >= n or (k-b) % 256 < p then
	 -- in this case either the cyclic buffer hasn't been filled yet, or
	 -- wrapping around would take us past the buffer pointer, so bail out
	 break
      else
	 -- wrap around to the end of the buffer
	 k = (k-b) % 256
      end
      l = l+b
   end
   -- grab l (at most m) steps
   --pd.post(string.format("loop: recorded %d/%d steps %d-%d", l, m, k+1, k+m))
   pd.post(string.format("loop: recorded %d/%d steps", l, m))
   local loop = {}
   for i = k+1, k+l do
      loop[i-k] = cycle(self.loop, i)
   end
   self.loop = loop
   self.loopidx = q % l
   self.loopstate = 1
end

function arpeggio:loop_add(notes, vel, gate)
   -- we only start recording at the first note
   local have_notes = type(notes) == "number" or
      (notes ~= nil and next(notes) ~= nil)
   if have_notes or next(self.loop) ~= nil then
      self.loop[self.loopidx+1] = {notes, vel, gate}
      -- we always *store* up to 256 steps in a cyclic buffer
      self.loopidx = (self.loopidx+1) % 256
   end
end

function arpeggio:loop_get()
   local res = {{}, 0, 0}
   local p, n = self.loopidx, math.min(#self.loop, self.loopsize)
   if p < n then
      res = self.loop[p+1]
      -- we always *read* exactly n steps in a cyclic buffer
      self:outlet(1, "loopidx", {self.loopidx})
      self.loopidx = (p+1) % n
   end
   return res
end

local function fexists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function arpeggio:loop_file(file, cmd)
   -- default for cmd is 1 (save) if loop is playing, 0 (load) otherwise
   cmd = cmd or self.loopstate
   if cmd == 1 then
      -- save: first create a backup copy if the file already exists
      if fexists(file) then
	 local k, bakname = 1, ""
	 repeat
	    bakname = string.format("%s~%d~", file, k)
	    k = k+1
	 until not fexists(bakname)
	 -- ignore errors, if we can't rename the file, we probably can't
	 -- overwrite it either
	 os.rename(file, bakname)
      end
      local f, err = io.open(file, "w")
      if type(err) == "string" then
	 pd.post(string.format("loop: %s", err))
	 return
      end
      -- shorten the table to the current loop size if needed
      local loop, n = {}, math.min(#self.loop, self.loopsize)
      table.move(self.loop, 1, n, 1, loop)
      -- add some pretty-printing
      local function bars(level, count)
	 if level == 1 and count%self.beats == 0 then
	    return string.format("-- bar %d", count//self.beats+1)
	 end
      end
      f:write(string.format("-- saved by Raptor %s\n", os.date()))
      f:write(inspect(loop, {extra = 1, addin = bars}))
      f:close()
      pd.post(string.format("loop: %s: saved %d steps", file, n))
   elseif cmd == 0 then
      -- load: check that file exists and is loadable
      local f, err = io.open(file, "r")
      if type(err) == "string" then
	 pd.post(string.format("loop: %s", err))
	 return
      end
      local fun, err = load("return " .. f:read("a"))
      f:close()
      if type(err) == "string" or type(fun) ~= "function" then
	 pd.post(string.format("loop: %s: invalid format", file))
      else
	 local loop = fun()
	 if type(loop) ~= "table" then
	    pd.post(string.format("loop: %s: invalid format", file))
	 else
	    self.loop = loop
	    self.loopsize = #loop
	    self.loopidx = self.idx % self.loopsize
	    self.loopstate = 1
	    pd.post(string.format("loop: %s: loaded %d steps", file, #loop))
	    self:outlet(1, "loopsize", {self.loopsize})
	 end
      end
   elseif cmd == 2 then
      -- check that file exists, report result on 1st outlet
      self:outlet(1, "loop", {fexists(file) and 1 or 0})
   end
end

function arpeggio:in_1_loopsize(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.loopsize = math.max(0, math.min(256, x))
      if self.loopstate == 1 then
	 -- need to update the loop index in case the loopsize changed
	 if self.loopsize > 0 then
	    -- also resynchronize the loop with the arpeggiator if needed
	    self.loopidx = math.max(self.idx, self.loopidx % self.loopsize)
	 else
	    self.loopidx = 0
	 end
      end
   end
end

function arpeggio:in_1_loop(x)
   if type(x) == "string" then
      x = {x}
   end
   if type(x) == "table" and type(x[1]) == "string" then
      -- file operations
      self:loop_file(table.unpack(x))
   else
      x = self:intarg(x)
      if type(x) == "number" then
	 if x ~= 0 and self.loopstate == 0 then
	    self:loop_set()
	 elseif x == 0 and self.loopstate == 1 then
	    self:loop_clear()
	 end
      end
   end
end

-- velocity tracking

function arpeggio:update_veltracker(chord, vel)
   if next(chord) == nil then
      -- reset
      self.minavg, self.maxavg = nil, nil
      if self.debug&2~=0 then
	 pd.post(string.format("min = %s, max = %s", self.minavg, self.maxavg))
      end
   elseif vel > 0 then
      -- calculate the velocity envelope
      if not self.minavg then
	 self.minavg = self.minvel
      end
      self.minavg = self.minavg*self.g + vel*(1-self.g)
      if not self.maxavg then
	 self.maxavg = self.maxvel
      end
      self.maxavg = self.maxavg*self.g + vel*(1-self.g)
      if self.debug&2~=0 then
	 pd.post(string.format("vel min = %g, max = %g", self.minavg, self.maxavg))
      end
   end
end

function arpeggio:velrange()
   if self.veltracker then
      local g = self.gain
      local min = self.minavg or self.minvel
      local max = self.maxavg or self.maxvel
      min = g*self.minvel + (1-g)*min
      max = g*self.maxvel + (1-g)*max
      return min, max
   else
      return self.minvel, self.maxvel
   end
end

-- output the next note in the pattern and switch to the next pulse
function arpeggio:in_1_bang()
   local w, n = self:meter(self.idx)
   -- normalized pulse strength
   local w1 = w/math.max(1,n-1)
   -- corresponding MIDI velocity
   local minvel, maxvel = self:velrange()
   local vel =
      math.floor(mod_value(minvel, maxvel, self.velmod, w1))
   self:outlet(3, "float", {n})
   self:outlet(2, "float", {w})
   local gate, notes = 0, nil
   if self.loopstate == 1 then
      -- notes come straight from the loop, input is ignored
      notes, vel, gate = table.unpack(self:loop_get())
      -- adjust velocities using gain value
      vel = vel*2^(2*self.gain-1)
      if type(notes) == "table" then
	 for _,note in ipairs(notes) do
	    self:outlet(1, "list", {note, vel, gate})
	 end
      else
	 self:outlet(1, "list", {notes, vel, gate})
      end
      self.idx = (self.idx + 1) % self.beats
      return
   end
   if type(self.pattern) == "function" then
      notes = self.pattern(w1)
   elseif next(self.pattern) ~= nil then
      notes = cycle(self.pattern, self.idx+1)
   end
   if notes ~= nil then
      -- note filtering
      local pmin, pmax = self.pmin, self.pmax
      -- Calculate the filter probablity. We allow for negative pmod values
      -- here, in which case stronger pulses tend to be filtered out first
      -- rather than weaker ones.
      local p = mod_value(pmin, pmax, self.pmod, w1)
      local r = math.random()
      if self.debug&4~=0 then
	 pd.post(string.format("w = %g, p = %g, r = %g", w1, p, r))
      end
      if r <= p then
	 -- modulated gate value
	 gate = mod_value(0, self.gate, self.gatemod, w1)
	 -- output notes (there may be more than one in Raptor mode)
	 if self.debug&4~=0 then
	    pd.post(string.format("idx = %g, notes = %s, vel = %g, gate = %g", self.idx, inspect(notes), vel, gate))
	 end
	 self:loop_add(notes, vel, gate)
	 if type(notes) == "table" then
	    for _,note in ipairs(notes) do
	       self:outlet(1, "list", {note, vel, gate})
	    end
	 else
	    -- just a single note (assert type(notes) == "number")
	    self:outlet(1, "list", {notes, vel, gate})
	 end
      else
	 self:loop_add({}, vel, gate)
      end
   else
      self:loop_add({}, vel, gate)
   end
   self.idx = (self.idx + 1) % self.beats
end

-- panic on the 1st inlet clears the chord memory and pattern
function arpeggio:in_1_panic()
   self.chord = {}
   self.pattern = {}
   self.last_q = nil
   self:in_1_hold(0)
   self:update_veltracker({}, 0)
end

-- float on the 1st inlet changes the current pulse
function arpeggio:in_1_float(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.idx = math.max(0, x) % self.beats
      if self.loopstate == 1 then
	 self.loopidx = self.idx % math.min(#self.loop, self.loopsize)
      end
   end
end

local function transp(chord, i)
   return map(chord, function (n) return n+12*i end)
end

function arpeggio:pitchrange(a, b)
   if self.pitchtracker == 0 then
      -- just octave range
      a = math.max(0, math.min(127, a+12*self.down))
      b = math.max(0, math.min(127, b+12*self.up))
   elseif self.pitchtracker == 1 then
      -- full range tracker
      a = math.max(0, math.min(127, a+12*self.down+self.pitchlo))
      b = math.max(0, math.min(127, b+12*self.up+self.pitchhi))
   elseif self.pitchtracker == 2 then
      -- treble tracker
      a = math.max(0, math.min(127, b+12*self.down+self.pitchlo))
      b = math.max(0, math.min(127, b+12*self.up+self.pitchhi))
   elseif self.pitchtracker == 3 then
      -- bass tracker
      a = math.max(0, math.min(127, a+12*self.down+self.pitchlo))
      b = math.max(0, math.min(127, a+12*self.up+self.pitchhi))
   end
   return seq(a, b)
end

function arpeggio:create_pattern(chord)
   -- create a new pattern using the current settings
   local pattern = chord
   -- By default we do outside-in by alternating up-down (i.e., lo-hi), set
   -- this flag to true to get something more Logic-like which goes down-up.
   local logic_like = false
   if next(pattern) == nil then
      -- nothing to see here, move along...
      return pattern
   elseif self.raptor ~= 0 then
      -- Raptor mode: Pick random notes from the eligible range based on
      -- average Barlow harmonicities (cf. barlow.lua). This also combines
      -- with mode 0..5, employing the corresponding Raptor arpeggiation
      -- modes. Note that these patterns may contain notes that we're not
      -- actually playing, if they're harmonically related to the input
      -- chord. Raptor can also play chords rather than just single notes, and
      -- with the right settings you can make it go from plain tonal to more
      -- jazz-like and free to completely atonal, and everything in between.
      local a, b = pattern[1], pattern[#pattern]
      -- NOTE: As this kind of pattern is quite costly to compute, we
      -- implement it as a closure which gets evaluated lazily for each pulse,
      -- rather than precomputing the entire pattern at once as in the
      -- deterministic modes.
      if self.mode == 5 then
	 -- Raptor by itself doesn't support mode 5 (outside-in), so we
	 -- emulate it by alternating between mode 1 and 2. This isn't quite
	 -- the same, but it's as close to outside-in as I can make it. You
	 -- might also consider mode 0 (random) as a reasonable alternative
	 -- instead.
	 local cache, mode, dir
	 local function restart()
	    -- pd.post("raptor: restart")
	    cache = {{}, {}}
	    if logic_like then
	       mode, dir = 2, -1
	    else
	       mode, dir = 1, 1
	    end
	 end
	 restart()
	 pattern = function(w1)
	    local notes, _
	    if w1 == 1 then
	       -- beginning of bar, restart pattern
	       restart()
	    end
	    notes, _ =
	       rand_notes(w1,
			  self.nmax, self.nmod,
			  self.hmin, self.hmax, self.hmod,
			  self.smin, self.smax, self.smod,
			  dir, mode, self.uniq ~= 0,
			  self.pref, self.prefmod,
			  cache[mode],
			  chord, self:pitchrange(a, b))
	    if next(notes) ~= nil then
	       cache[mode] = notes
	    end
	    if dir>0 then
	       mode, dir = 2, -1
	    else
	       mode, dir = 1, 1
	    end
	    return notes
	 end
      else
	 local cache, mode, dir
	 local function restart()
	    -- pd.post("raptor: restart")
	    cache = {}
	    mode = self.mode
	    dir = 0
	    if mode == 1 or mode == 3 then
	       dir = 1
	    elseif mode == 2 or mode == 4 then
	       dir = -1
	    end
	 end
	 restart()
	 pattern = function(w1)
	    local notes
	    if w1 == 1 then
	       -- beginning of bar, restart pattern
	       restart()
	    end
	    notes, dir =
	       rand_notes(w1,
			  self.nmax, self.nmod,
			  self.hmin, self.hmax, self.hmod,
			  self.smin, self.smax, self.smod,
			  dir, mode, self.uniq ~= 0,
			  self.pref, self.prefmod,
			  cache,
			  chord, self:pitchrange(a, b))
	    if next(notes) ~= nil then
	       cache = notes
	    end
	    return notes
	 end
      end
   else
      -- apply the octave range (not used in raptor mode)
      pattern = {}
      for i = self.down, self.up do
	 pattern = tabcat(pattern, transp(chord, i))
      end
      if self.mode == 0 then
	 -- random: this is just the run-of-the-mill random pattern permutation
	 local n, pat = #pattern, {}
	 local p = seq(1, n)
	 for i = 1, n do
	    local j = math.random(i, n)
	    p[i], p[j] = p[j], p[i]
	 end
	 for i = 1, n do
	    pat[i] = pattern[p[i]]
	 end
	 pattern = pat
      elseif self.mode == 1 then
	 -- up (no-op)
      elseif self.mode == 2 then
	 -- down
	 pattern = reverse(pattern)
      elseif self.mode == 3 then
	 -- up-down
	 local r = reverse(pattern)
	 -- get rid of the repeated note in the middle
	 table.remove(pattern)
	 pattern = tabcat(pattern, r)
      elseif self.mode == 4 then
	 -- down-up
	 local r = reverse(pattern)
	 table.remove(r)
	 pattern = tabcat(reverse(pattern), pattern)
      elseif self.mode == 5 then
	 -- outside-in
	 local n, pat = #pattern, {}
	 local p, q = n//2, n%2
	 if logic_like then
	    for i = 1, p do
	       -- highest note first (a la Logic?)
	       pat[2*i-1] = pattern[n+1-i]
	       pat[2*i] = pattern[i]
	    end
	 else
	    for i = 1, p do
	       -- lowest note first (sounds better IMHO)
	       pat[2*i-1] = pattern[i]
	       pat[2*i] = pattern[n+1-i]
	    end
	 end
	 if q > 0 then
	    pat[n] = pattern[p+1]
	 end
	 pattern = pat
      end
   end
   if self.debug&1~=0 then
      pd.post(string.format("chord = %s", inspect(chord)))
      pd.post(string.format("pattern = %s", inspect(pattern)))
   end
   return pattern
end

function arpeggio:get_chord()
   return self.hold and self.hold or self.chord
end

-- hold: keep chord notes around until reset
function arpeggio:in_1_hold(x)
   x = self:intarg(x)
   if type(x) == "number" then
      if x ~= 0 then
	 self.hold = {table.unpack(self.chord)}
      elseif self.hold then
	 self.hold = nil
	 self.pattern = self:create_pattern(self.chord)
      end
   end
end

-- change the range of the pattern
function arpeggio:in_1_up(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.up = math.max(-2, math.min(2, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

function arpeggio:in_1_down(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.down = math.max(-2, math.min(2, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

function arpeggio:in_1_pitchtracker(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.pitchtracker = math.max(0, math.min(3, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

function arpeggio:in_1_pitchlo(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.pitchlo = math.max(-36, math.min(36, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

function arpeggio:in_1_pitchhi(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.pitchhi = math.max(-36, math.min(36, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

-- change the mode (up, down, etc.)
function arpeggio:in_1_mode(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.mode = math.max(0, math.min(5, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

-- this enables Raptor mode with randomized note output
function arpeggio:in_1_raptor(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.raptor = math.max(0, math.min(1, x))
      self.pattern = self:create_pattern(self:get_chord())
   end
end

-- change min/max velocities, gate, and note probabilities
function arpeggio:in_1_minvel(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.minvel = math.max(0, math.min(127, x))
   end
end

function arpeggio:in_1_maxvel(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.maxvel = math.max(0, math.min(127, x))
   end
end

function arpeggio:in_1_velmod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.velmod = math.max(-100, math.min(100, x))/100
   end
end

function arpeggio:in_1_veltracker(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.veltracker = math.max(0, math.min(1, x))
   end
end

local function midiccval(x)
   -- pesky midi cc values aren't properly centered; do some magic to get a
   -- fudged normalization where 64 maps to exactly 0.5
   return x<127 and x/128 or 1.0 -- snaps to 1 at max
end

function arpeggio:in_1_gain(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.gain = midiccval(math.max(0, math.min(127, x)))
   end
end

function arpeggio:in_1_gate(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.gate = math.max(0, math.min(1000, x))/100
   end
end

function arpeggio:in_1_gatemod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.gatemod = math.max(-100, math.min(100, x))/100
   end
end

function arpeggio:in_1_pmin(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.pmin = math.max(0, math.min(100, x))/100
   end
end

function arpeggio:in_1_pmax(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.pmax = math.max(0, math.min(100, x))/100
   end
end

function arpeggio:in_1_pmod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.pmod = math.max(-100, math.min(100, x))/100
   end
end

-- change the raptor parameters (harmonicity, etc.)
function arpeggio:in_1_nmax(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.nmax = math.max(0, math.min(10, x))
   end
end

function arpeggio:in_1_nmod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.nmod = math.max(-100, math.min(100, x))/100
   end
end

function arpeggio:in_1_hmin(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.hmin = math.max(0, math.min(100, x))/100
   end
end

function arpeggio:in_1_hmax(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.hmax = math.max(0, math.min(100, x))/100
   end
end

function arpeggio:in_1_hmod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.hmod = math.max(-100, math.min(100, x))/100
   end
end

function arpeggio:in_1_smin(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.smin = math.max(-127, math.min(127, x))
   end
end

function arpeggio:in_1_smax(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.smax = math.max(-127, math.min(127, x))
   end
end

function arpeggio:in_1_smod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.smod = math.max(-100, math.min(100, x))/100
   end
end

function arpeggio:in_1_uniq(x)
   x = self:intarg(x)
   if type(x) == "number" then
      self.uniq = math.max(0, math.min(1, x))
   end
end

function arpeggio:in_1_pref(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.pref = math.max(-100, math.min(100, x))/100
   end
end

function arpeggio:in_1_prefmod(x)
   x = self:numarg(x)
   if type(x) == "number" then
      self.prefmod = math.max(-100, math.min(100, x))/100
   end
end

local function update_chord(chord, note, vel)
   -- update the chord memory, keeping the notes in ascending order
   local n = #chord
   if n == 0 then
      if vel > 0 then
	 table.insert(chord, 1, note)
      end
      return chord
   end
   for i = 1, n do
      if chord[i] == note then
	 if vel <= 0 then
	    -- note off: remove note
	    if i < n then
	       table.move(chord, i+1, n, i)
	    end
	    table.remove(chord)
	 end
	 return chord
      elseif chord[i] > note then
	 if vel > 0 then
	    -- insert note
	    table.insert(chord, i, note)
	 end
	 return chord
      end
   end
   -- if we come here, no note has been inserted or deleted yet
   if vel > 0 then
      -- note is larger than all present notes in chord, so it needs to be
      -- inserted at the end
      table.insert(chord, note)
   end
   return chord
end

-- note-vel pair on the 1st inlet updates the internal chord memory and
-- recomputes the pattern
function arpeggio:in_1_list(x)
   local note, vel = table.unpack(x)
   if self.debug&2~=0 then
      pd.post(string.format("note = %s", inspect(x)))
   end
   if type(note) == "number" and type(vel) == "number" then
      update_chord(self.chord, note, vel)
      if self.hold and vel>0 then
	 update_chord(self.hold, note, vel)
      end
      self.pattern = self:create_pattern(self:get_chord())
      self:update_veltracker(self:get_chord(), vel)
   end
end

-- this recomputes all indispensability tables
function arpeggio:prepare_meter(atoms)
   local n = 1
   local m = {}
   for _,q in ipairs(atoms) do
      if q ~= math.floor(q) then
	 self:error("arpeggio: meter levels must be integer")
	 return
      elseif q < 1 then
	 self:error("arpeggio: meter levels must be positive")
	 return
      end
      -- factorize each level as Barlow's formula assumes primes
      m = tabcat(m, factor(q))
      n = n*q
   end
   self.beats = n
   self.last_q = nil
   if n > 1 then
      self.indisp[1] = indisp(m)
      for q = 2, self.n do
	 local qs = tabcat(m, factor(q))
	 self.indisp[q] = indisp(qs)
      end
   else
      self.indisp[1] = {0}
      for q = 2, self.n do
	 self.indisp[q] = indisp(q)
      end
   end
end

-- a meter on the 2nd inlet sets the new meter and outputs the number of
-- pulses on the 3rd outlet
function arpeggio:in_2_list(atoms)
   self:prepare_meter(atoms)
   self:outlet(3, "float", {self.beats})
end

-- the meter may also be given as a singleton value on the 2nd inlet
function arpeggio:in_2_float(f)
   self:in_2_list({f})
end
