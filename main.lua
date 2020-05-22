function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

function table.size(t)
  local count = 0
  for _ in pairs(t) do count=count+1 end
  return count
end

function table.print(t)
  print(table.tostring(t))
end

function table.tostring(t)
  if type(t) ~= 'table' then
    return tostring(t)
  else
    local s = ''
    local i = 1
    while t[i] ~= nil do
      if #s ~= 0 then s = s..', ' end
      s = s..table.tostring(t[i])
      i = i+1
    end
    for k, v in pairs(t) do
      if type(k) ~= 'number' or k > i then
        if #s ~= 0 then s = s..', ' end
        local key = type(k) == 'string' and k or '['..table.tostring(k)..']'
        s = s..key..'='..table.tostring(v)
      end
    end
    return '{'..s..'}'
  end
end

-- Some shortcuts
local clear = love.graphics.clear
local line, rect = love.graphics.line, love.graphics.rectangle
local color = love.graphics.setColor

local WHITE = { 1, 1, 1, 1 }
local BLACK = { 0, 0, 0, 1 }

local CHAR_SIZE = 8
local CHAR_SPACE = 2

-- Data structures
local ip_id = 4
local ips = {
  [1] = {x=20, y=20, id=1},
  [2] = {x=20, y=580, id=2},
  [3] = {x=780, y=20, id=3},
  [4] = {x=780, y=580, id=4},
}
local features = {}
local current_ip = nil
local current_feature_inputs = {}
local current_feature = nil

function distance(x1, y1, x2, y2)
  local dx, dy = x2-x1, y2-y1

  return math.sqrt(dx*dx+dy*dy)
end

-- TODO: check input before pluggin into features
function feature_character(p)
  return {x = p.x, y = p.y+CHAR_SIZE*2}, {x = p.x, y = p.y+CHAR_SIZE*6}, {x = p.x, y = p.y+CHAR_SPACE}, {x = p.x+CHAR_SIZE, y = p.y}
end

function feature_character_visible(p)
  rect("fill", p.x, p.y, CHAR_SIZE-CHAR_SPACE, CHAR_SIZE)
end

function feature_underline(a, b)
  return {x = (b.x-a.x)/2, y = (b.y-a.y)/2}
end

function feature_underline_visible(a, b)
  line(a.x, a.y, b.x, b.y)
  line(a.x, a.y, a.x, a.y-2)
  line(b.x, b.y, b.x, b.y-2)
end

function nearest_ip(x, y)
  local d = nil
  local nearest = nil

  for _, ip in pairs(ips) do
    local tmp_d = distance(ip.x, ip.y, x, y)

    if d then
      if tmp_d < d then
        d = tmp_d
        nearest = ip
      end
    else
      d = tmp_d
      nearest = ip
    end
  end

  return nearest
end

function add_ip(x, y)
  ip_id = ip_id+1

  ips[ip_id] = {id=ip_id, x=x, y=y}

  return ip_id
end

function compute_feature(f)
  local inputs = {}

  for _, ip in ipairs(f.inputs) do
    table.insert(inputs, ips[ip])
  end

  local returns = { f.fn(unpack(inputs)) }

  for i, ip in ipairs(f.outputs) do
    ips[ip].x = returns[i].x
    ips[ip].y = returns[i].y
  end
end

function compute_features()
  for _, feature in ipairs(features) do
    compute_feature(feature)
  end
end

function draw_feature(f)
  local inputs = {}

  for _, ip in ipairs(f.inputs) do
    table.insert(inputs, ips[ip])
  end

  f.draw(unpack(inputs))
end

function draw_features()
  for _, feature in ipairs(features) do
    draw_feature(feature)
  end

  -- preview
  if current_feature and current_ip then
    local inputs = { unpack(current_feature_inputs) }

    table.insert(inputs, current_ip.id)

    if #inputs == current_feature.args then
      draw_feature({
          fn = current_feature.fn,
          draw = current_feature.draw,
          inputs = inputs,
          outputs = outputs,
      })
    end
  end
end

function check_edit_completion()
  if current_feature and current_feature.args == #current_feature_inputs then
    local outputs = {}

    for i=1,current_feature.outs do
      table.insert(outputs, add_ip(0, 0))
    end

    table.insert(features, {
                   fn = current_feature.fn,
                   draw = current_feature.draw,
                   inputs = { unpack(current_feature_inputs) },
                   outputs = outputs,
    })

    current_feature = nil
    current_feature_inputs = {}
  end

  -- FIXME: this does not take into account the dependencies
  compute_features()
end

function add_feature_argument()
  -- Is adding a feature?
  if current_feature then
    if #current_feature_inputs < current_feature.args then
      if current_ip then
        table.insert(current_feature_inputs, current_ip.id)
      end
    end
  end

  check_edit_completion()
end

function love.load()
  color(WHITE)
end

function love.draw()
  clear(BLACK)

  draw_features()
end

function love.mousemoved(x, y, dx, dy, istouch)
  current_ip = nearest_ip(x, y)
end

function love.mousepressed(x, y, button, istouch, presses)
  add_feature_argument()
end

function love.keypressed(k, scancode, isrepeat)
  if not isrepeat then
    if k ~= "u" then
      print("Editing 'character' feature")

      current_feature = {
        fn = feature_character,
        draw = feature_character_visible,
        args = 1,
        outs = 4,
      }

      add_feature_argument()

      -- Auto advance
      current_ip = ips[ip_id]
    elseif k == "u" then
      print("Editing 'underline' feature")

      current_feature = {
        fn = feature_underline,
        draw = feature_underline_visible,
        args = 2,
        outs = 1,
      }
    end
  end
end
