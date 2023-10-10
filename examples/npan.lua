-- Ported to lua from john gibson's NPAN from rtcmix
-- https://github.com/RTcmix/RTcmix/blob/master/insts/jg/NPAN/speakers.cpp

local npan = {
	speakers = {}
}

local MINDIST = 0.25

Speaker = {
	channel = 0,
	angle = 0,
	prevAngle = 0,
	nextAngle = 0,
	distance = 0
}

function Speaker:new(chan, angle, dist)
	local o = {channel=chan, angle=angle, distance=dist}
	setmetatable(o, self)
	self.__index = self
	return o
end

function speaker_sorting(a, b)
	return a.angle < b.angle
end

function npan.set_speakers(args)
	local num_speakers = #args/2
	for i=1,num_speakers do
		local angle = math.pi * (args[i * 2 - 1] + 90) / 180
		angle = math.atan2(math.sin(angle), math.cos(angle)) -- normalize
		local dist = args[i * 2]
		npan.speakers[i] = Speaker:new(i, angle, dist)		
	end
	
	table.sort(npan.speakers, speaker_sorting)
	
	for i=1,num_speakers do
		if (i==1) then
			npan.speakers[i].prevAngle = npan.speakers[num_speakers].angle - math.pi * 2
		else	
			npan.speakers[i].prevAngle = npan.speakers[i - 1].angle
		end
		
		if (i==num_speakers) then
			npan.speakers[i].nextAngle = npan.speakers[1].angle + math.pi * 2
		else	
			npan.speakers[i].nextAngle = npan.speakers[i + 1].angle
		end
	end
	
end

function npan.get_gains(src_angle, src_distance)
	if (src_distance < MINDIST) then
		src_distance = MINDIST
	end
	
	src_angle = math.pi * (src_angle + 90) / 180 
	src_angle = math.atan2(math.sin(src_angle), math.cos(src_angle)) -- normalize
	
	local gains = {}
	
	for i, spk in ipairs(npan.speakers) do
		local source_angle = src_angle
		if (i == 1 and src_angle > 0.0) then
			source_angle = src_angle - 2 * math.pi
		elseif (i == #npan.speakers and src_angle < 0.0) then
			source_angle = src_angle + 2 * math.pi
		end
		if (source_angle > spk.prevAngle and source_angle < spk.nextAngle) then
			local scale = 0
			if (source_angle < spk.angle) then
				scale = (spk.angle - spk.prevAngle) * 2 / math.pi
			else
				scale = (spk.nextAngle - spk.angle) * 2 / math.pi
			end
			
			local diff = math.abs(source_angle - spk.angle) / scale
			local distfactor = spk.distance / src_distance
			gains[spk.channel] = math.cos(diff) * distfactor
			
		else
			gains[spk.channel] = 0
		end
		
		
	end
	
	return gains
end

function npan.test()
	npan.set_speakers({45, 1,   -- front left
      -45, 1,   -- front right
       90, 1,   -- side left
      -90, 1,   -- side right
      135, 1,   -- rear left
     -135, 1,   -- rear right rear
        0, 1,   -- front center
      180, 1 	-- rear center
	  })
	
	for i, v in ipairs(npan.speakers) do
		print(string.format("prev: %f angle: %f next : %f, ", v.prevAngle, v.angle, v.nextAngle))
	end
	
	local gains = npan.get_gains(120, 1)
	local output = "gains : "
	for i, v in ipairs(gains) do
		output = output .. string.format("%f, ", v)
	end
	print(output)

end

return npan