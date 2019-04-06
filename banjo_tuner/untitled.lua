engine.name = 'TestSine'


local root = 128

local notes = {1, 3/2, 2, 9/4, 3/1}
local pos = 1
local pitch = 0


function init()
  p = poll.set("pitch_in_l")
  p.callback = function(val) 
    if val > 0 then
      print("in > "..string.format("%.2f",val))
      pitch = val 
      redraw()
    end
  end
  p.time = 0.08
  p:start()
end

function redraw()
  screen.clear()
  screen.move(0,10)
  screen.text(pitch)
  screen.move(0,40)
  screen.text(root * notes[pos])
  
  screen.update()
end

function enc(n,d)
  if n == 2 then
    pos = util.clamp(pos + d, 1, #notes)
    redraw()
  elseif n == 3 then
  end
end