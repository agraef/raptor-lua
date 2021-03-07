-- Pd external to compute rhythmic patterns using Barlow's indispensability
-- method from the Ratio book (Feedback Papers, Cologne, 2001)

-- Lua version Copyright (c) 2017 by Albert Gräf <aggraef@gmail.com>

-- Distributed under the GPLv3+, please check the accompanying COPYING file
-- for details.

local Meter = pd.Class:new():register("meter")

-- INVOCATION: [meter -n n p1 p2 ...], where n and the pi are positive
-- integers. All arguments are optional. The -n option specifies the maximum
-- number of subdivisions of the base meter. This number can only be specified
-- at creation time and should be a reasonably small value -- the default
-- value of 7 seems to work best in the current implementation, and will allow
-- q-toles of up to 7 notes to be handled accurately. The sequence p1 p2
-- ... can be used to specify the initial meter (otherwise "common time" 4 is
-- assumed by default).

-- METER STRATIFICATION: Barlow's algorithm actually requires a "stratified"
-- meter which explicitly specifies all the prime subdivisions in the right
-- order. Our meter object is a bit more lenient in that it will accept the
-- meter as a sequence of arbitrary positive integers which are automatically
-- decomposed into their prime factors. Thus, e.g., the meter 4 will be
-- stratified as 2-2 and 12 will become 2-2-3. Note that the "auto-stratified"
-- prime factors are always listed in ascending order, so that higher primes
-- appear at lower levels of the meter, which matches musical tradition (at
-- least in the simple cases). If the auto-stratified meter doesn't match
-- your expectations then you'll have to specify the prime subdivisions
-- explicitly in the right order.

-- COMPUTING BEAT STRENGTHS: Once the initial meter has been set up during
-- object creation, you can query the object for beat strengths by sending a
-- beat index to its left inlet. Beat indices are zero-based, so they range
-- from 0 to the total number N of beats (the product of p1 p2 ...) minus
-- one. The given beat indices will be taken modulo N, so you can also just
-- keep counting up from 0, but given Pd's limited number precision it's
-- usually better to set up a cyclic beat counter on the Pd side instead, if
-- you know the modulus beforehand -- or you'd want to reset the counter at
-- least whenever the meter changes.

-- For each beat index, the total number N of beats will be reported on the
-- right outlet, followed by the computed beat strength on the left
-- outlet. The beat strengths are also in the range from 0 to N-1, so each
-- beat gets a unique weight which can be mapped to various values such as
-- velocities, note numbers or note probabilities. The total number of beats
-- output on the right outlet helps with that since it makes it easy to
-- normalize the beat strengths (e.g., dividing the strength value by N-1,
-- i.e., the reported total number of beats minus one).

-- FRACTIONAL BEATS: Beat indices can also include a fractional part, the
-- "phase" which denotes a subdivision of the beat. Thus, e.g., 2.5 denotes
-- the pulse halfway through beat #2, 2.33 the second note of a triplet,
-- etc. The meter object automagically chooses the subdivision which matches
-- the given phase most closely in order to compute a reasonable subdivision
-- pulse strength, using the precomputed tables for all subdivisions up to n
-- (the value given with the -n option when creating the object, or 7 by
-- default). Note that in this case the total number of pulses output on the
-- right outlet will be adjusted automatically, so that it corresponds to the
-- chosen subdivision, giving a value of N*q where q is the chosen subdivision
-- in the range from 1 to n. Thus, e.g., if you're running a 4 a.k.a. 2-2
-- base meter (common time) then sending a beat index of 2.33 will give you a
-- pulse strength for a 12 (2-2-3) meter, so 12 will be output on the right
-- outlet along with a pulse strength in the range from 0 to 11 on the left
-- outlet.

-- By these means you almost never need to worry about subdivisions of the
-- base meter, they will usually be handled automatically without any further
-- ado -- as long as the desired accuracy doesn't exceed the range of
-- precomputed subdivisions, at which point you'll have to refine your base
-- meter specification accordingly. Note that the best matching subdivision q
-- is computed for each individual pulse, which allows on-the-fly adjustments
-- of the subdivision grid of the main meter like, e.g., quickly switching
-- from power-of-2 subdivisions to q-toles for any value q <= n.

-- DYNAMIC METER CHANGES: Finally, it is possible the change the base meter at
-- any time by feeding a singleton number or a list of numbers p1 p2 ... into
-- the right inlet. This causes all internal indispensability tables to be
-- recomputed and thus is a relatively expensive operation. Therefore it's
-- generally advisable to protect this inlet with a [change] object so that
-- the tables are only recomputed when the meter actually changes.

function Meter:initialize(name, atoms)
   self.inlets = 2
   self.outlets = 2
   self.n = 7 -- seems to work reasonably well up to 7-toles
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
   if #atoms == 0 then
      atoms = {4} -- default meter (common time)
   end
   -- initialize the indispensability tables and reset the beat counter
   self.indisp = {}
   self:in_2_list(atoms)
   return true
end

-- Computes the best subdivision q in the range 1..n and pulse p in the range
-- 0..q so that p/q matches the given phase f in the floating point range 0..1
-- as closely as possible. Returns p, q and the absolute difference between f
-- and p/q. NB: Seems to work best for q values up to 7.

function subdiv(n, f)
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

-- prime factors of integers
local function factor(n)
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

-- reverse a table

local function reverse(list)
   local res = {}
   for k, v in ipairs(list) do
      table.insert(res, 1, v)
   end
   return res
end

-- arithmetic sequences

local function seq(from, to, step)
   step = step or 1;
   local sgn = step>=0 and 1 or -1
   local res = {}
   while sgn*(to-from) >= 0 do
      table.insert(res, from)
      from = from + step
   end
   return res
end

-- some functional programming goodies

local function map(list, fn)
   local res = {}
   for k, v in ipairs(list) do
      table.insert(res, fn(v))
   end
   return res
end

local function reduce(list, acc, fn)
   for k, v in ipairs(list) do
      acc = fn(acc, v)
   end
   return acc
end

local function collect(list, acc, fn)
   local res = {acc}
   for k, v in ipairs(list) do
      acc = fn(acc, v)
      table.insert(res, acc)
   end
   return res
end

local function sum(list)
   return reduce(list, 0, function(a,b) return a+b end)
end

local function prd(list)
   return reduce(list, 1, function(a,b) return a*b end)
end

local function sums(list)
   return collect(list, 0, function(a,b) return a+b end)
end

local function prds(list)
   return collect(list, 1, function(a,b) return a*b end)
end

-- indispensabilities

local function indisp(q)
   function ind(q, k)
      -- prime indispensabilities
      function pind(q, k)
	 function ind1(q, k)
	    local i = ind(reverse(factor(q-1)), k)
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
      local s = prds(q)
      local t = reverse(prds(reverse(q)))
      return
	 sum(
	    map(seq(1, #q),
		function(i)
		   return s[i] *
		      pind(q[i], (math.floor((k-1) % t[1] / t[i+1]) + 1) % q[i])
		end
	 ))
   end
   if type(q) == "number" then
      q = factor(q)
   end
   if type(q) ~= "table" then
      error("invalid argument, must be an integer or table of primes")
   else
      return map(seq(0,prd(q)-1), function(k) return ind(q,k) end)
   end
end

function tableconcat(t1,t2)
   local res = {}
   for i=1,#t1 do
      table.insert(res, t1[i])
   end
   for i=1,#t2 do
      table.insert(res, t2[i])
   end
   return res
end

-- On the first inlet we expect a zero-based beat number, optionally with a
-- phase in the fractional part to indicate a sub-pulse below the beat level.
-- We then compute the closest matching subdivision and output the
-- corresponding pulse weight, using the precomputed indispensability tables.
function Meter:in_1_float(f)
   if f < 0 then
      self:error("meter: beat index must be nonnegative")
      return
   end
   local beat, f = math.modf(f)
   -- take the beat index modulo the total number of beats
   beat = beat % self.beats
   if self.n > 0 then
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
      self:outlet(2, "float", {self.beats*q})
      self:outlet(1, "float", {w})
   else
      local w = self.indisp[1][beat+1]
      self:outlet(2, "float", {self.beats})
      self:outlet(1, "float", {w})
   end
end

-- a new meter on the 2nd inlet recomputes all indispensability tables
function Meter:in_2_list(atoms)
   local n = 1
   local m = {}
   for i,q in ipairs(atoms) do
      if q ~= math.floor(q) then
	 self:error("meter: levels must be integer")
	 return
      elseif q < 1 then
	 self:error("meter: levels must be positive")
	 return
      end
      -- factorize each level as Barlow's formula assumes primes
      m = tableconcat(m, factor(q))
      n = n*q
   end
   self.beats = n
   self.last_q = nil
   if self.beats > 1 then
      self.indisp[1] = indisp(m)
      for q = 2, self.n do
	 local qs = tableconcat(m, factor(q))
	 self.indisp[q] = indisp(qs)
      end
   else
      self.indisp[1] = {0}
      for q = 2, self.n do
	 self.indisp[q] = indisp(q)
      end
   end
end

-- the meter may also be given as a singleton value on the 2nd inlet
function Meter:in_2_float(f)
   self:in_2_list({f})
end
