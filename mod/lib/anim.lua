-- Per-tick jobs: land rising from the sea, pods falling from orbit, pods
-- launching off the terminal. Each job is a table in storage.q.jobs with a
-- `kind`; a handler returns true when the job is finished.

local W = require("lib.world")

local A = {}

local handlers = {}

function A.register(kind, fn)
  handlers[kind] = fn
end

function A.add(job)
  local q = storage.q
  q.jobs[#q.jobs + 1] = job
end

function A.tick()
  local q = storage.q
  if not q or #q.jobs == 0 then return end
  -- Handlers may add jobs; they land in the fresh list and run next tick.
  local jobs = q.jobs
  q.jobs = {}
  for _, job in ipairs(jobs) do
    local fn = handlers[job.kind]
    local done = true
    if fn then done = fn(job) end
    if not done then q.jobs[#q.jobs + 1] = job end
  end
end

A.register("rise", W.rise_step)

-- A pod that lifts off from `pos` and fades out (a shipment leaving).
function A.launch(surface, pos)
  local sprite = rendering.draw_sprite({
    sprite = "quota-pod", surface = surface, target = { pos.x, pos.y - 1 },
    x_scale = 0.9, y_scale = 0.9, render_layer = "air-object",
  })
  A.add({ kind = "launch", obj = sprite, x = pos.x, y = pos.y - 1, t = 0 })
end

A.register("launch", function(job)
  local obj = job.obj
  if not (obj and obj.valid) then return true end
  job.t = job.t + 1
  local t = job.t
  -- Ease in: slow lift-off, then away.
  obj.target = { job.x, job.y - 0.002 * t * t }
  local a = math.max(0, 1 - t / 75)
  obj.color = { a, a, a, a }
  if t >= 75 then
    obj.destroy()
    return true
  end
  return false
end)

return A
