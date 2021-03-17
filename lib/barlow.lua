-- Various helper functions to compute Barlow meters and harmonicities using
-- the methods from Clarence Barlow's Ratio book (Feedback Papers, Cologne,
-- 2001)

-- Author: Albert Gräf <aggraef@gmail.com>, Dept. of Music-Informatics,
-- Johannes Gutenberg University (JGU) of Mainz, Germany, please check
-- https://agraef.github.io/ for a list of my software.

-- Copyright (c) 2021 by Albert Gräf <aggraef@gmail.com>

-- Distributed under the GPLv3+, please check the accompanying COPYING file
-- for details.

local M = {}

-- list helper functions

-- concatenate tables
function M.tableconcat(t1, t2)
   local res = {}
   for i=1,#t1 do
      table.insert(res, t1[i])
   end
   for i=1,#t2 do
      table.insert(res, t2[i])
   end
   return res
end

-- reverse a table
function M.reverse(list)
   local res = {}
   for _, v in ipairs(list) do
      table.insert(res, 1, v)
   end
   return res
end

-- arithmetic sequences
function M.seq(from, to, step)
   step = step or 1;
   local sgn = step>=0 and 1 or -1
   local res = {}
   while sgn*(to-from) >= 0 do
      table.insert(res, from)
      from = from + step
   end
   return res
end

-- cycle through a table
function M.cycle(t, i)
   local n = #t
   if n > 0 then
      while i > n do
	 i = i - n
      end
   end
   return t[i]
end

-- some functional programming goodies

function M.map(list, fn)
   local res = {}
   for _, v in ipairs(list) do
      table.insert(res, fn(v))
   end
   return res
end

function M.reduce(list, acc, fn)
   for _, v in ipairs(list) do
      acc = fn(acc, v)
   end
   return acc
end

function M.collect(list, acc, fn)
   local res = {acc}
   for _, v in ipairs(list) do
      acc = fn(acc, v)
      table.insert(res, acc)
   end
   return res
end

function M.sum(list)
   return M.reduce(list, 0, function(a,b) return a+b end)
end

function M.prd(list)
   return M.reduce(list, 1, function(a,b) return a*b end)
end

function M.sums(list)
   return M.collect(list, 0, function(a,b) return a+b end)
end

function M.prds(list)
   return M.collect(list, 1, function(a,b) return a*b end)
end

-- Determine the prime factors of an integer. The result is a list with the
-- prime factors in non-decreasing order.

function M.factor(n)
   local factors = {}
   if n<0 then n = -n end
   while n % 2 == 0 do
      table.insert(factors, 2)
      n = math.floor(n / 2)
   end
   local p = 3
   while p <= math.sqrt(n) do
      while n % p == 0 do
	 table.insert(factors, p)
	 n = math.floor(n / p)
      end
      p = p + 2
   end
   if n > 1 then -- n must be prime
      table.insert(factors, n)
   end
   return factors
end

-- Collect the factors of the integer n and return them as a list of pairs
-- {p,k} where p are the prime factors in ascending order and k the
-- corresponding (nonzero) multiplicities. If the given number is a pair {p,
-- q}, considers p/q as a rational number and returns its prime factors with
-- positive or negative multiplicities.

function M.factors(x)
   if type(x) == "table" then
      local n, m = table.unpack(x)
      local pfs, nfs, mfs = {}, M.factors(n), M.factors(m)
      -- merge the factors in nfs and mfs into a single list
      local i, j, k, N, M = 1, 1, 1, #nfs, #mfs
      while i<=N or j<=M do
	 if j>M or (i<=N and mfs[j][1]>nfs[i][1]) then
	    pfs[k] = nfs[i]
	    k = k+1; i = i+1
	 elseif i>N or (j<=M and nfs[i][1]>mfs[j][1]) then
	    pfs[k] = mfs[j]
	    pfs[k][2] = -mfs[j][2]
	    k = k+1; j = j+1
	 else
	    pfs[k] = nfs[i]
	    pfs[k][2] = nfs[i][2] - mfs[j][2]
	    k = k+1; i = i+1; j = j+1
	 end
      end
      return pfs
   else
      local pfs, pf = {}, M.factor(x)
      if next(pf) then
	 local j, n = 1, #pf
	 pfs[j] = {pf[1], 1}
	 for i = 2, n do
	    if pf[i] == pfs[j][1] then
	       pfs[j][2] = pfs[j][2] + 1
	    else
	       j = j+1
	       pfs[j] = {pf[i], 1}
	    end
	 end
      end
      return pfs
   end
end

-- Probability functions. These are used with some of the random generation
-- functions below.

-- Create random permutations. Chooses n random values from a list ms of input
-- values according to a probability distribution given by a list ws of
-- weights. NOTES: ms and ws should be of the same size, otherwise excess
-- elements will be chosen at random. In particular, if ws is empty or missing
-- then shuffle(n, ms) will simply return n elements chosen from ms at random
-- using a uniform distribution. ms and ws and are modified *in place*,
-- removing chosen elements, so that their final contents will be the elements
-- *not* chosen and their corresponding weight distribution.

function M.shuffle(n, ms, ws)
   local res = {}
   if ws == nil then
      -- simply choose elements at random, uniform distribution
      ws = {}
   end
   while next(ms) ~= nil and n>0 do
      -- accumulate weights
      local sws = M.sums(ws)
      local s = sws[#sws]
      table.remove(sws, 1)
      -- pick a random index
      local k, r = 0, math.random()*s
      --print("r = ", r, "sws = ", table.unpack(sws))
      for i = 1, #sws do
	 if r < sws[i] then
	    k = i; break
	 end
      end
      -- k may be out of range if ws and ms aren't of the same size, in which
      -- case we simply pick an element at random
      if k==0 or k>#ms then
	 k = math.random(#ms)
      end
      table.insert(res, ms[k])
      n = n-1; table.remove(ms, k);
      if k<=#ws then
	 table.remove(ws, k)
      end
   end
   return res
end

-- Calculate modulated values. This is used for all kinds of parameters which
-- can vary automatically according to pulse strength, such as note
-- probability, velocity, gate, etc.

function M.mod_value(x1, x2, b, w)
   -- x2 is the nominal value which is always output if b==0. As b increases
   -- or decreases, the range extends downwards towards x1. (Normally,
   -- x2>x1, but you can reverse bounds to have the range extend upwards.)
   if b >= 0 then
      -- positive bias: mod_value(w) -> x1 as w->0, -> x2 as w->1
      -- zero bias: mod_value(w) == x2 (const.)
      return x2-b*(1-w)*(x2-x1)
   else
      -- negative bias: mod_value(w) -> x1 as w->1, -> x2 as w->0
      return x2+b*w*(x2-x1)
   end
end

-- Barlow meters. This stuff is mostly a verbatim copy of the guts of
-- meter.pd_lua, please check that module for details.

-- Computes the best subdivision q in the range 1..n and pulse p in the range
-- 0..q so that p/q matches the given phase f in the floating point range 0..1
-- as closely as possible. Returns p, q and the absolute difference between f
-- and p/q. NB: Seems to work best for q values up to 7.

function M.subdiv(n, f)
   local best_p, best_q, best = 0, 0, 1
   for q = 1, n do
      local p = math.floor(f*q+0.5) -- round towards nearest pulse
      local diff = math.abs(f-p/q)
      if diff < best then
	 best_p, best_q, best = p, q, diff
      end
   end
   return best_p, best_q, best
end

-- Compute pulse strengths according to Barlow's indispensability formula from
-- the Ratio book.

function M.indisp(q)
   local function ind(q, k)
      -- prime indispensabilities
      local function pind(q, k)
	 local function ind1(q, k)
	    local i = ind(M.reverse(M.factor(q-1)), k)
	    local j = i >= math.floor(q / 4) and 1 or 0;
	    return i+j
	 end
	 if q <= 3 then
	    return (k-1) % q
	 elseif k == q-2 then
	    return math.floor(q / 4)
	 elseif k == q-1 then
	    return ind1(q, k-1)
	 else
	    return ind1(q, k)
	 end
      end
      local s = M.prds(q)
      local t = M.reverse(M.prds(M.reverse(q)))
      return
	 M.sum(M.map(M.seq(1, #q), function(i) return s[i] * pind(q[i], (math.floor((k-1) % t[1] / t[i+1]) + 1) % q[i]) end))
   end
   if type(q) == "number" then
      q = M.factor(q)
   end
   if type(q) ~= "table" then
      error("invalid argument, must be an integer or table of primes")
   else
      return M.map(M.seq(0,M.prd(q)-1), function(k) return ind(q,k) end)
   end
end

-- Barlow harmonicities from the Ratio book. These are mostly ripped out of an
-- earlier version of the Raptor random arpeggiator programs (first written in
-- Q, then rewritten in Pure, and now finally ported to Lua).

-- Some "standard" 12 tone scales and prime valuation functions to play with.
-- Add others as needed. We mostly use the just scale and the standard Barlow
-- valuation here.

M.just = -- standard just intonation, a.k.a. the Ptolemaic (or Didymic) scale
   {  {1,1}, {16,15}, {9,8}, {6,5}, {5,4}, {4,3}, {45,32},
      {3,2}, {8,5}, {5,3}, {16,9}, {15,8}, {2,1}  }
M.pyth = -- pythagorean (3-limit) scale
   {  {1,1}, {2187,2048}, {9,8}, {32,27}, {81,64}, {4,3}, {729,512},
      {3,2}, {6561,4096}, {27,16}, {16,9}, {243,128}, {2,1}  }
M.mean4 = -- 1/4 comma meantone scale, Barlow (re-)rationalization
   {  {1,1}, {25,24}, {10,9}, {6,5}, {5,4}, {4,3}, {25,18},
      {3,2}, {25,16}, {5,3}, {16,9}, {15,8}, {2,1}  }

function M.barlow(p)	return 2*(p-1)*(p-1)/p end
function M.euler(p)	return p-1 end
-- "mod 2" versions (octave is eliminated)
function M.barlow2(p)	if p==2 then return 0 else return M.barlow(p) end end
function M.euler2(p)	if p==2 then return 0 else return M.euler(p) end end

-- Harmonicity computation.

-- hrm({p,q}, pv) computes the disharmonicity of the interval p/q using the
-- prime valuation function pv.

-- hrm_dist({p1,q1}, {p2,q2}, pv) computes the harmonic distance between two
-- pitches, i.e., the disharmonicity of the interval between {p1,q1} and
-- {p2,q2}.

-- hrm_scale(S, pv) computes the disharmonicity metric of a scale S, i.e., the
-- pairwise disharmonicities of all intervals in the scale. The input is a
-- list of intervals as {p,q} pairs, the output is the distance matrix.

function M.hrm(x, pv)
   return M.sum(M.map(M.factors(x),
	function(f) local p, k = table.unpack(f)
	   return math.abs(k) * pv(p)
	end))
end

function M.hrm_dist(x, y, pv)
   local p1, q1 = table.unpack(x)
   local p2, q2 = table.unpack(y)
   return M.hrm({p1*q2,p2*q1}, pv)
end

function M.hrm_scale(S, pv)
   return M.map(S,
	function(s)
	   return M.map(S, function(t) return M.hrm_dist(s, t, pv) end)
	end)
end

-- Some common tables for convenience and testing. These are all based on a
-- standard 12-tone just tuning. NOTE: The given reference tables use rounded
-- values, but are good enough for most practical purposes; you might want to
-- employ these to avoid the calculation cost.

-- Barlow's "indigestibility" harmonicity metric
-- M.bgrad = {0,13.07,8.33,10.07,8.4,4.67,16.73,3.67,9.4,9.07,9.33,12.07,1}
M.bgrad = M.map(M.just, function(x) return M.hrm(x, M.barlow) end)

-- Euler's "gradus suavitatis" (0-based variant)
-- M.egrad = {0,10,7,7,6,4,13,3,7,6,8,9,1}
M.egrad = M.map(M.just, function(x) return M.hrm(x, M.euler) end)

-- In an arpeggiator we might want to treat different octaves of the same
-- pitch as equivalent, in which case we can use the following "mod 2" tables:
M.bgrad2 = M.map(M.just, function(x) return M.hrm(x, M.barlow2) end)
M.egrad2 = M.map(M.just, function(x) return M.hrm(x, M.euler2) end)

-- But in the following we stick to the standard Barlow table.
M.grad = M.bgrad

-- Calculate the harmonicity of the interval between two (MIDI) notes.
function M.hm(n, m)
   local d = math.max(n, m) - math.min(n, m)
   return 1/(1+M.grad[d%12+1])
end

-- Use this instead if you also want to keep account of octaves.
function M.hm2(n, m)
   local d = math.max(n, m) - math.min(n, m)
   return 1/(1+M.grad[d%12+1]+(d//12)*M.grad[13])
end

-- Calculate the average harmonicity (geometric mean) of a MIDI note relative
-- to a given chord (specified as a list of MIDI notes).
function M.hv(ns, m)
   if next(ns) ~= nil then
      local xs = M.map(ns, function(n) return M.hm(m, n) end)
      return M.prd(xs)^(1/#xs)
   else
      return 1
   end
end

-- Sort the MIDI notes in ms according to descending average harmonicities
-- w.r.t. the MIDI notes in ns. This allows you to quickly pick the "best"
-- (harmonically most pleasing) MIDI notes among given alternatives ms
-- w.r.t. a given chord ns.
function M.besthv(ns, ms)
   local mhv = M.map(ms, function(m) return {m, M.hv(ns, m)} end)
   table.sort(mhv, function(x, y) return x[2]>y[2] or
		 (x[2]==y[2] and x[1]<y[1]) end)
   return M.map(mhv, function(x) return x[1] end)
end

-- Randomized note filter. This is the author's (in)famous Raptor algorithm.
-- It needs a whole bunch of parameters, but also delivers much more
-- interesting results and can produce randomized chords as well. Basically,
-- it performs a random walk guided by Barlow harmonicities and
-- indispensabilities. The parameters are:

-- ns: input notes (chord memory of the arpeggiator, as in besthv these are
-- used to calculate the average harmonicities)

-- ms: candidate output notes (these will be filtered and participate in the
-- random walk)

-- w: indispensability value used to modulate the various parameters

-- nmax, nmod: range and modulation of the density (maximum number of notes
-- in each step)

-- smin, smax, smod: range and modulation of step widths, which limits the
-- steps between notes in successive pulses

-- dir, mode, uniq: arpeggio direction (0 = random, 1 = up, -1 = down), mode
-- (0 = random, 1 = up, 2 = down, 3 = up-down, 4 = down-up), and whether
-- repeated notes are disabled (uniq flag)

-- hmin, hmax, hmod: range and modulation of eligible harmonicities, which are
-- used to filter candidate notes based on average harmonicities w.r.t. the
-- input notes

-- pref, prefmod: range and modulation of harmonic preference. This is
-- actually one of the most important and effective parameters in the Raptor
-- algorithm which drives the random note selection process. A pref value
-- between -1 and 1 determines the weighted probabilities used to pick notes
-- at random. pref>0 gives preference to notes with high harmonicity, pref<0
-- to notes with low harmonicity, and pref==0 ignores harmonicity (in which
-- case all eligible notes are chosen with the same probability). The prefs
-- parameter can also be modulated by pulse strengths as indicated by prefmod
-- (prefmod>0 lowers preference on weak pulses, prefmod<0 on strong pulses).

function M.harm_filter(w, hmin, hmax, hmod, ns, ms)
   -- filters notes according to harmonicities and a given pulse weight w
   if next(ns) == nil then
      -- empty input (no eligible notes)
      return {}
   else
      local res = {}
      for _,m in ipairs(ms) do
	 local h = M.hv(ns, m)
	 -- modulate: apply a bias determined from hmod and w
	 if hmod > 0 then
	    h = h^(1-hmod*(1-w))
	 elseif hmod < 0 then
	    h = h^(1+hmod*w)
	 end
	 -- check that the (modulated) harmonicity is within prescribed bounds
	 if h>=hmin and h<=hmax then
	    table.insert(res, m)
	 end
      end
      return res
   end
end

function M.step_filter(w, smin, smax, smod, dir, mode, cache, ms)
   -- filters notes according to the step width parameters and pulse weight w,
   -- given which notes are currently playing (the cache)
   if next(ms) == nil or dir == 0 then
      return ms, dir
   end
   local res = {}
   while next(res) == nil do
      if next(cache) ~= nil then
	 -- non-empty cache, going any direction
	 local lo, hi = cache[1], cache[#cache]
	 -- NOTE: smin can be negative, allowing us, say, to actually take a
	 -- step *down* while going upwards. But we always enforce that smax
	 -- is non-negative in order to avoid deadlock situations where *no*
	 -- step is valid anymore, and even restarting the pattern doesn't
	 -- help. (At least that's what I think, I don't really recall what
	 -- the original rationale behind all this was, but since it's in the
	 -- original Raptor code, it must make sense somehow. ;-)
	 smax = math.max(0, smax)
	 smax = math.floor(M.mod_value(math.abs(smin), smax, smod, w)+0.5)
	 local function valid_step_min(m)
	    if dir==0 then
	       return (m>=lo+smin) or (m<=hi-smin)
	    elseif dir>0 then
	       return m>=lo+smin
	    else
	       return m<=hi-smin
	    end
	 end
	 local function valid_step_max(m)
	    if dir==0 then
	       return (m>=lo-smax) and (m<=hi+smax)
	    elseif dir>0 then
	       return (m>=lo+math.min(0,smin)) and (m<=hi+smax)
	    else
	       return (m>=lo-smax) and (m<=hi-math.min(0,smin))
	    end
	 end
	 for _,m in ipairs(ms) do
	    if valid_step_min(m) and valid_step_max(m) then
	       table.insert(res, m)
	    end
	 end
      elseif dir == 1 then
	 -- empty cache, going up, start at bottom
	 local lo = ms[1]
	 local max = math.floor(M.mod_value(smin, smax, smod, w)+0.5)
	 for _,m in ipairs(ms) do
	    if m <= lo+max then
	       table.insert(res, m)
	    end
	 end
      elseif dir == -1 then
	 -- empty cache, going down, start at top
	 local hi = ms[#ms]
	 local max = math.floor(M.mod_value(smin, smax, smod, w)+0.5)
	 for _,m in ipairs(ms) do
	    if m >= hi-max then
	       table.insert(res, m)
	    end
	 end
      else
	 -- empty cache, random direction, all notes are eligible
	 return ms, dir
      end
      if next(res) == nil then
	 -- we ran out of notes, restart the pattern
	 -- pd.post("raptor: no notes to play, restart!")
	 cache = {}
	 if mode==0 then
	    dir = 0
	 elseif mode==1 or (mode==3 and dir==0) then
	    dir = 1
	 elseif mode==2 or (mode==4 and dir==0) then
	    dir = -1
	 else
	    dir = -dir
	 end
      end
   end
   return res, dir
end

function M.uniq_filter(uniq, cache, ms)
   -- filters out repeated notes (removing notes already in the cache),
   -- depending on the uniq flag
   if not uniq or next(ms) == nil or next(cache) == nil then
      return ms
   end
   local res = {}
   local i, j, k, N, M = 1, 1, 1, #cache, #ms
   while i<=N or j<=M do
      if j>M then
	 -- all elements checked, we're done
	 return res
      elseif i>N or ms[j]<cache[i] then
	 -- current element not in cache, add it
	 res[k] = ms[j]
	 k = k+1; j = j+1
      elseif ms[j]>cache[i] then
	 -- look at next cache element
	 i = i+1
      else
	 -- current element in cache, skip it
	 i = i+1; j = j+1
      end
   end
   return res
end

function M.pick_notes(w, n, pref, prefmod, ns, ms)
   -- pick n notes from the list ms of eligible notes according to the
   -- given harmonic preference
   local ws = {}
   -- calculate weighted harmonicities based on preference; this gives us the
   -- probability distribution for the note selection step
   local p = M.mod_value(0, pref, prefmod, w)
   if p==0 then
      -- no preference, use uniform distribution
      for i = 1, #ms do
	 ws[i] = 1
      end
   else
      for i = 1, #ms do
	 -- "Frankly, I don't know where the exponent came from," probably
	 -- experimentation. ;-)
	 ws[i] = M.hv(ns, ms[i]) ^ (p*10)
      end
   end
   return M.shuffle(n, ms, ws)
end

-- The note generator. This is invoked with the current pulse weight w, the
-- current cache (notes played in the previous step), the input notes ns, the
-- candidate output notes ms, and all the other parameters that we need
-- (density: nmax, nmod; harmonicity: hmin, hmax, hmod; step width: smin,
-- smax, smod; arpeggiator state: dir, mode, uniq; harmonic preference: pref,
-- prefmod). It returns a selection of notes chosen at random for the given
-- parameters, along with the updated direction dir of the arpeggiator.

function M.rand_notes(w, nmax, nmod,
		      hmin, hmax, hmod,
		      smin, smax, smod,
		      dir, mode, uniq,
		      pref, prefmod,
		      cache,
		      ns, ms)
   -- uniqueness filter: remove repeated notes
   local res = M.uniq_filter(uniq, cache, ms)
   -- harmonicity filter: select notes based on harmonicity
   res = M.harm_filter(w, hmin, hmax, hmod, ns, res)
   -- step filter: select notes based on step widths and arpeggiator state
   -- (this must be the last filter!)
   res, dir = M.step_filter(w, smin, smax, smod, dir, mode, cache, res)
   -- pick notes
   local n = math.floor(M.mod_value(1, nmax, nmod, w)+0.5)
   res = M.pick_notes(w, n, pref, prefmod, ns, res)
   return res, dir
end

return M
