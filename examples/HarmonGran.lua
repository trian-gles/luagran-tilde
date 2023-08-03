-- basic template for usage



local granmodule = {}
granmodule.state = {}

function randrange(m, n)
    return math.random() * (n - m) + m
end

function octfreq(linocts)
    return 2^linocts
end

function granmodule.init()
    granmodule.state.rate = 1
    granmodule.state.lastFund = octfreq(randrange(6, 8))
	granmodule.state.lastPart = 1
	granmodule.state.dir = 1
	granmodule.state.chance = 0.5
	
	granmodule.state.grainsRemaining = 4000
end

function granmodule.generate()
    -- create parameters for a grain and modify state if needed
	if (math.random() > granmodule.state.chance) then
		granmodule.state.lastPart = granmodule.state.lastPart + granmodule.state.dir * math.random()
	else 
		granmodule.state.lastPart = granmodule.state.lastPart + granmodule.state.dir
	end
	
	if (granmodule.state.lastPart >= 24) then
		granmodule.state.dir = -1
	elseif (granmodule.state.lastPart < 2) then
		granmodule.state.dir = 1
	end
	
	
	if (granmodule.state.grainsRemaining == 0) then
		rate = math.random(1000, 4000)
		granmodule.state.grainsRemaining = math.random(1000, 4000)
		granmodule.state.lastFund = octfreq(randrange(6, 8))
		granmodule.state.rate = 0.5 + math.random()
	else 
		rate = granmodule.state.rate
		granmodule.state.grainsRemaining = granmodule.state.grainsRemaining - 1
	end
	
	if (granmodule.state.grainsRemaining < 100) then
		dur = math.random(80, 400)
	else
		dur = math.random(10, 70)
	end
    
    freq = granmodule.state.lastFund * granmodule.state.lastPart 
    amp = 4 / (granmodule.state.lastPart^(.5)) 
    pan = math.random()
	
	

    return rate, dur, freq, amp, pan
end

function granmodule.update(...)
    -- receives updates from lists sent to the object as args
    granmodule.state.chance = ...
end

return granmodule

