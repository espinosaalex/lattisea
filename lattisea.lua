-- earthsea
--
-- subtractive polysynth
-- controlled by midi or grid
--
-- grid pattern player:
-- 1 1 record toggle
-- 1 2 play toggle
-- 1 8 transpose mode

local tab = require 'tabutil'
local pattern_time = require 'pattern_time'

local g = grid.connect()

local mode_transpose = 0
local root = { x=5, y=5 }
local trans = { x=5, y=5 }
local lit = {}

local screen_framerate = 15
local screen_refresh_metro

local MAX_NUM_VOICES = 16

engine.name = 'PolySub'

local layoutint = 4

local latlit = 15
local lvl = 4
local dim = 1
local levels = {lvl, lvl, lvl, lvl, lvl, lvl, lvl, lvl, lvl, lvl, lvl, lvl}
local start = {4, 8}
local width = 100
local height = 36
local right = width/3
local down = height/2
local offset = 0
local scales = {
  {{1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1}, "lydian"},
  {{1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1}, "ionian"},
  {{1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0}, "mixolydian"},
  {{1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0}, "dorian"},
  {{1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0}, "aeolian"},
  {{1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0}, "phrygian"}
}

local show = 0
local position = 1
local interval = 0
local amp1 = 0.8
local count = 1

local intervals = {
  {1, "sa", {right, down}},
  {16/15, "k-re", {0, down * 2}},
  {9/8, "re", {right * 3, down}},
  {6/5, "k-ga", {right * 2, down * 2}},
  {5/4, "ga", {right, 0}},
  {4/3, "ma", {0, down}},
  {45/32, "t-ma", {right * 3, 0}},
  {3/2, "pa", {right * 2, down}},
  {8/5, "k-dha", {right, down * 2}},
  {5/3, "dha", {0, 0}},
  {9/5, "k-ni", {right * 3, down * 2}},
  {15/8, "ni", {right * 2, 0}}
}

local center = 1
local roothz = 32
local base = roothz

local screens = {notes={lit={},pat={}}, transpose={lit={},pat={}}, rhythm={lit={},pat={}}}
local current_screen = "notes"



local function getHzJust(note)
  ratio = intervals[(note % 12) + 1][1]
  oct = math.floor(note / 12) + 1
  return(base * 2^oct * ratio)
end

local function getNewBase(note)
  ratio = intervals[(note % 12) + 1][1]
  oct = math.floor(note / 12) + 1
  base = roothz * 2^oct * ratio
end

local function highlight_on(note)
  levels[(note % 12) + 1] = latlit
end

local function highlight_off(note)
  levels[(note % 12) + 1] = lvl
end

local function highlight_all_off()
  for i = 1, #scale do
    levels[i] = lvl
  end
end


-- current count of active voices
local nvoices = 0

function init()
  for i,v in pairs(screens) do
    local event_type = ""
    if i == "notes" then event_type = grid_note
    elseif i == "transpose" then event_type = grid_note_trans
    -- elseif i == 2 then event_type = grid_note_rhythm
    end
    for n=1,4 do
      screens[i].pat[n] = pattern_time.new()
      screens[i].pat[n].process = event_type
    end
  end

  scale = scales[1][1]
  pat = pattern_time.new()
  pat.process = grid_note

  params:add{type="number",id="layoutint",name="layoutint",min=1,max=12,default=4,action=function(n) layoutint=n end}
  params:add{type="number",id="center",name="center",min=1,max=12,default=1,action=function(n) base = roothz * intervals[n][1] end}
  params:add_control("shape", "shape", controlspec.new(0,1,"lin",0,0,""))
  params:set_action("shape", function(x) engine.shape(x) end)

  params:add_control("timbre", "timbre", controlspec.new(0,1,"lin",0,0.5,""))
  params:set_action("timbre", function(x) engine.timbre(x) end)

  params:add_control("noise", "noise", controlspec.new(0,1,"lin",0,0,""))
  params:set_action("noise", function(x) engine.noise(x) end)

  params:add_control("cut", "cut", controlspec.new(0,32,"lin",0,8,""))
  params:set_action("cut", function(x) engine.cut(x) end)

  params:add_control("fgain", "fgain", controlspec.new(0,6,"lin",0,0,""))
  params:set_action("fgain", function(x) engine.fgain(x) end)

  params:add_control("cutEnvAmt", "cutEnvAmt", controlspec.new(0,1,"lin",0,0,""))
  params:set_action("cutEnvAmt", function(x) engine.cutEnvAmt(x) end)

  params:add_control("detune", "detune", controlspec.new(0,1,"lin",0,0,""))
  params:set_action("detune", function(x) engine.detune(x) end)

  params:add_control("ampAtk", "ampAtk", controlspec.new(0.01,10,"lin",0,0.05,""))
  params:set_action("ampAtk", function(x) engine.ampAtk(x) end)

  params:add_control("ampDec", "ampDec", controlspec.new(0,2,"lin",0,0.1,""))
  params:set_action("ampDec", function(x) engine.ampDec(x) end)

  params:add_control("ampSus", "ampSus", controlspec.new(0,1,"lin",0,1,""))
  params:set_action("ampSus", function(x) engine.ampSus(x) end)

  params:add_control("ampRel", "ampRel", controlspec.new(0.01,10,"lin",0,1,""))
  params:set_action("ampRel", function(x) engine.ampRel(x) end)

  params:add_control("cutAtk", "cutAtk", controlspec.new(0.01,10,"lin",0,0.05,""))
  params:set_action("cutAtk", function(x) engine.cutAtk(x) end)

  params:add_control("cutDec", "cutDec", controlspec.new(0,2,"lin",0,0.1,""))
  params:set_action("cutDec", function(x) engine.cutDec(x) end)

  params:add_control("cutSus", "cutSus", controlspec.new(0,1,"lin",0,1,""))
  params:set_action("cutSus", function(x) engine.cutSus(x) end)

  params:add_control("cutRel", "cutRel", controlspec.new(0.01,10,"lin",0,1,""))
  params:set_action("cutRel", function(x) engine.cutRel(x) end)


  engine.level(0.05)
  engine.stopAll()

  params:read("lattisea.pset")

  params:bang()

  if g then gridredraw() end

end

function g.key(x, y, z)
  local pat = screens[current_screen].pat[1]
  if x == 1 then
    if z == 1 then
      if y == 1 and pat.rec == 0 then
        -- trans.x = 5
        -- trans.y = 5
        pat:stop()
        engine.stopAll()
        highlight_all_off()
        pat:clear()
        pat:rec_start()
      elseif y == 1 and pat.rec == 1 then
        pat:rec_stop()
        if pat.count > 0 then
          -- root.x = pat.event[1].x
          -- root.y = pat.event[1].y
          -- trans.x = root.x
          -- trans.y = root.y
          pat:start()
        end
      elseif y == 2 and pat.play == 0 and pat.count > 0 then
        if pat.rec == 1 then
          pat:rec_stop()
        end
        pat:start()
      elseif y == 2 and pat.play == 1 then
        pat:stop()
        engine.stopAll()
        nvoices = 0
        screens[current_screen].lit = {}
      elseif y == 7 then
        current_screen = "transpose"
      elseif y == 8 then
        current_screen = "notes"
      end
    end

  else
    if current_screen == "notes" then
      local e = {}
      e.id = x*8 + y
      e.x = x
      e.y = y
      e.state = z
      pat:watch(e)
      grid_note(e)
    elseif current_screen == "transpose" then
      local trans = {}
      trans.id = x*8 + y
      trans.x = x
      trans.y = y
      trans.state = z
      pat:watch(trans)
      grid_note_trans(trans)
    end
  end
  gridredraw()
end


function grid_note(e)
  local lit = screens.notes.lit
  local note = ((7-e.y)*layoutint) + e.x
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      --engine.start(id, getHz(x, y-1))
      --print("grid > "..id.." "..note)
      --added Just
      engine.start(e.id, getHzJust(note))
      highlight_on(note)
      lit[e.id] = {}
      lit[e.id].x = e.x
      lit[e.id].y = e.y
      nvoices = nvoices + 1
    end
  else
    if lit[e.id] ~= nil then
      engine.stop(e.id)
      highlight_off(note)
      lit[e.id] = nil
      nvoices = nvoices - 1
    end
  end
  gridredraw()
end

function grid_note_trans(e)
  highlight_all_off()
  screens.transpose.lit = {}
  local lit = screens.transpose.lit
  local note = (((7-e.y)*layoutint) + e.x) - 24
      --engine.start(id, getHz(x, y-1))
      --print("grid > "..id.." "..note)
      --added Just
  getNewBase(note)
  highlight_on(note)
  lit[e.id] = {}
  lit[e.id].x = e.x
  lit[e.id].y = e.y
  gridredraw()
end

function gridredraw()
  local pat = screens[current_screen].pat[1]
  g:all(0)

  gridscale(scale)

  g:led(1,1,2 + pat.rec * 10)
  g:led(1,2,2 + pat.play * 10)
  g:led(1,7,2)
  g:led(1,8,2)

  -- if current_screen = notes sfsdfsf

  if current_screen == "notes" then
    g:led(1,8,12)
    for i,e in pairs(screens.notes.lit) do
      g:led(e.x, e.y,15)
    end
  elseif current_screen == "transpose" then
    g:led(1,7,12)
    g:led(4,5,10)
    for i,e in pairs(screens.transpose.lit) do
      g:led(e.x, e.y,15)
    end
  end
  g:refresh()
  redraw()
end

function gridscale(scale)
  for x = 2, 16 do
    for y = 1, 8 do
      ind = ((7-y)*layoutint) + x
      if ind%12 == 0 then g:led(x, y, 6)
      elseif scale[(ind % 12) + 1] == 1 then g:led(x, y, 3) end
    end
  end
end

function enc(n,d)
    if n == 2 then
      amp1 = amp1 + d
    elseif n == 3 then
      if d > 0 then
        count = count + 1
        if count > #scales then count = 1 end
        scale = scales[count][1]

      elseif d < 0 then
        count = count - 1
        if count <= 0 then count = #scales end
        scale = scales[count][1]
      end
      gridredraw()
      redraw()
    end

end

function key(n,z)
end

function redraw()
  screen.clear()
  screen.move(124, 60)
  screen.level(lvl)
  screen.font_size(12)
  screen.font_face(10)
  screen.text_right(scales[count][2])
  dim_notes(scale)
  drawlattice(scale)
  screen.update()
end

function dim_notes(scale)
  for i = 1, #scale do
    if levels[i] < latlit then
      if scale[i] == 1 then levels[i] = lvl
      else levels[i] = dim
      end
    end
  end
end

function drawlattice(scale)
  screen.font_face(0)
  screen.font_size(8)
  screen.move(start[1], start[2])
  for x = 1, #intervals do
    screen.move(intervals[x][3][1] + start[1], intervals[x][3][2]+ start[2])
    screen.level(levels[x])
    screen.text(intervals[x][2])

  end
end

function drawscale(scale)
end


function cleanup()
  engine.stopAll()
  pat:stop()
  pat = nil
end
