
{graphics: g} = love

import BloodEmitter, DirtEmitter from require "particles"

S = (name, fn) ->
  with Sequence fn
    .name = name

export show_properties = (t) ->
  require("moon").p { k,v for k,v in pairs t when type(v) != "table" }

-- on_ground: is on ground
-- wall_running: is wall running
-- can_wall_jump: allowed to wall jump, set to true when jump key released
-- ledge_grabbing: currently attached to ledge
class Player extends Entity
  is_player: true

  speed: 100
  jump_power: 200

  on_ground: false
  movement_locked: false
  dampen_movement: 1
  run_scale: 1

  w: 10
  h: 20

  lazy sprite: -> Spriter "images/protagonist.png"

  new: (x,y) =>
    super x, y
    @seqs = DrawList!
    @seqs.annotate = true
    @effects = EffectList!

    @velocity = Vec2d 0,0
    @facing = "left"

    rate = 0.08

    with @sprite
      @anim = StateAnim "stand_left", {
        stand_left: \seq {
          "6,9,21,26"
          ox: 6
          oy: 3
          flip_x: true
        }

        stand_right: \seq {
          ox: 5
          oy: 3
          "6,9,21,26"
        }

        jump_left: \seq {
          "69,10,21,26"
          ox: 6
          oy: 3
          flip_x: true
        }

        jump_right: \seq {
          ox: 5
          oy: 3
          "69,10,21,26"
        }

        run_left: \seq {
          "6,72,21,26"
          "38,72,21,26"
          "70,72,21,26"
          "102,72,21,26"
          ox: 5
          oy: 4
          flip_x: true
          :rate
        }

        run_right: \seq {
          "6,72,21,26"
          "38,72,21,26"
          "70,72,21,26"
          "102,72,21,26"
          ox: 4
          oy: 4
          :rate
        }

        wall_run_left: \seq {
          "14,97,21,26"
          "45,97,21,26"
          "77,97,21,26"
          "109,97,21,26"
          ox: 3
          oy: 4
          flip_x: true
          :rate
        }

        wall_run_right: \seq {
          "14,97,21,26"
          "45,97,21,26"
          "77,97,21,26"
          "109,97,21,26"
          ox: 9
          oy: 4
          :rate
        }

        attack_left: \seq {
          "7,171,34,22"
          "71,171,34,22"
          "135,171,34,22"
          "198,171,34,22"

          ox: 19
          oy: 1
          flip_x: true
          :rate
        }

        attack_right: \seq {
          "7,171,34,22"
          "71,171,34,22"
          "135,171,34,22"
          "198,171,34,22"

          ox: 5
          oy: 1
          :rate
        }

        grab_left: \seq {
          "135,9,21,26"
          ox: 5
          oy: 7
        }

        grab_right: \seq {
          "135,9,21,26"
          flip_x: true
          ox: 6
          oy: 7
        }

        down_stab_right: \seq {
          "105,233,18,26"
          "73,233,18,26"
          "39,233,18,26"
          "9,233,18,26"
          once: true
          :rate
          ox: 3
          oy: 3
        }

        down_stab_left: \seq {
          "105,233,18,26"
          "73,233,18,26"
          "39,233,18,26"
          "9,233,18,26"
          once: true
          :rate
          flip_x: true
          ox: 5
          oy: 3
        }


      }

  draw: (...) =>
    if DEBUG
      if @wall_running
        COLOR\push 100,255,100, 50
      else
        COLOR\pusha 50

      super ...

      COLOR\pop!

    @effects\before!
    @anim\draw @x, @y
    @effects\after!

    if DEBUG and @attack_box
      Box.outline @attack_box

  update: (dt, @world) =>
    @effects\update dt

    if @on_ground and not @attacking
      @anim\update dt * @run_scale
    else
      @anim\update dt

    @seqs\update dt, @world

    @position_attack_box!

    if @ledge_grabbing
      @update_for_ledge_grab dt
    elseif @wall_running
      @update_for_wall_run dt
    else
      @update_for_gravity dt

    if not @can_attack
      @can_attack = not CONTROLLER\is_down "attack"

    true

  update_for_ledge_grab: (dt) =>
    dx, dy = unpack CONTROLLER\movement_vector! * dt * @speed
    @on_ground = false

    dir = @ledge_grabbing.is_left and "left" or "right"
    @anim\set_state "grab_#{dir}"

    @world.map
    @ledge_grabbing.tid

    @y = @ledge_grabbing.tile.y

    if not @can_ledge_jump
      @can_ledge_jump = not CONTROLLER\is_down "jump"

    if @can_ledge_jump and CONTROLLER\is_down "jump"
      @ledge_jump dx, dy

  update_for_wall_run: (dt) =>
    dx, dy = unpack CONTROLLER\movement_vector! * dt * @speed
    @on_ground = false

    @anim\set_state "wall_run_#{@wall_run_up_key}"

    unless @feet_emitter
      @feet_emitter = with DirtEmitter @world, @x, @y, @wall_run_up_key
        .update = (...) ->
          unless @wall_running
            @feet_emitter = false
            return false
          DirtEmitter.update ...

      @world.particles\add @feet_emitter

    @feet_emitter.x, @feet_emitter.y = @feet_position!

    if CONTROLLER\is_down @wall_run_up_key
      @velocity[2] = -math.abs(dx) * @speed
    else
      if @velocity[2] < 0
        @velocity[2] = 0

      @velocity += @world.gravity * dt

    if not @can_wall_jump
      @can_wall_jump = not CONTROLLER\is_down "jump"

    if @can_wall_jump and CONTROLLER\is_down "jump"
      @jump @world

    cx, cy = @fit_move @velocity[1] * dt, @velocity[2] * dt, @world

    -- see if hit ledge zone
    for zone in *@world.ledge_zones\get_touching @
      @ledge_grab zone
      break

    moving_away = if @wall_run_up_key == "left"
      dx > 0
    else
      dx < 0

    -- stop if moving away, not against wall anymore or moving opposite direction
    if not @against_wall(@wall_run_up_key) or cy or moving_away
      @seqs\remove @wall_running
      @end_wall_run!

  -- slow the dx based on how long they've been holding direciton
  movement_vector: (dt) =>
    dx, dy = unpack CONTROLLER\movement_vector! * dt * @speed

    if CONTROLLER\is_down "left"
      if not @left_down_time
        @left_down_time = 0
    else
      @left_down_time = nil

    if CONTROLLER\is_down "right"
      unless @right_down_time
        @right_down_time= 0
    else
      @right_down_time = nil

    if @left_down_time and @on_ground
      @left_down_time += dt

    if @right_down_time and @on_ground
      @right_down_time += dt

    accel_time = 0.2
    elapsed = if dx > 0
      @right_down_time
    elseif dx < 0
      @left_down_time

    if elapsed
      @run_scale = math.min(accel_time, elapsed) / accel_time * 0.4 + 0.6
      dx = @run_scale * dx

    dx, dy

  update_for_gravity: (dt) =>
    dx, dy = if @taking_hit
      0,0
    else
      @movement_vector dt

    if dx != 0
      @facing = if dx < 0 then "left" else "right"

    unless @taking_hit
      if CONTROLLER\is_down "jump"
        @jump!
      elseif CONTROLLER\is_down "attack"
        @attack not @on_ground and dy > 0

    motion = if @attacking
      "attack"
    elseif not @on_ground
      "jump"
    elseif dx != 0
      "run"
    else
      "stand"

    if @stab_attacking
      @anim\set_state "down_stab_#{@stab_attacking}"
    else
      @anim\set_state "#{motion}_#{@facing}"

    @velocity += @world.gravity * dt
    -- air resistance
    if @velocity[1] != 0
      air_rate = 1
      if dx != 0 and not (dx < 0 and @velocity[1] < 0)
        air_rate *= 3

      @velocity[1] = dampen @velocity[1], dt * 200

    vx, vy = unpack @velocity
    vx += dx * @speed * @dampen_movement

    cx, cy = @fit_move vx * dt, vy * dt, @world

    if cx
      against, wx, wy = @against_wall @facing
      if against
        root_tile = @world.map\get_wall_root wx, wy
        -- try to initiate wall run
        @wall_run root_tile

    if cy
      if @velocity[2] > 0
        @on_ground = true
      @velocity[2] = 0
    else
      if math.floor(@velocity[2] * dt) != 0
        @on_ground = false

    if @on_ground == true
      @last_wall_tile = nil

  feet_position: =>
    return unless @wall_running

    if @wall_run_up_key == "left"
      @x, @y + @h - 5
    else
      @x + @w, @y + @h - 5

  wall_test_coords: (dir) =>
    ep = 0.1
    wy = @y + @h * 4 / 5 -- around the feet?

    wx = switch dir
      when "left"
        @x - ep
      when "right"
        @x + @w + ep
      else
        error "unknown dir #{dir}"

    wx, wy

  against_wall: (dir) =>
    wx, wy = @wall_test_coords dir

    return false unless @world.map\collides_pt wx, wy
    {:map} = @world
    solid = map.layers[map.solid_layer]

    idx = map\pt_to_idx wx, wy

    switch dir
      when "left" -- moving left
        moved = map\move_idx idx, 1, 1
        return false if solid[moved]
      when "right" -- moving right
        moved = map\move_idx idx, -1, 1
        return false if solid[moved]
      else
        error "unknown direction #{dir}"

    true, wx, wy

  ledge_grab: (zone) =>
    @end_wall_run!
    @ledge_grabbing = zone
    @can_ledge_jump = false

  wall_run: (wall_tile) =>
    return if @on_ground
    return if @wall_running
    return if wall_tile == @last_wall_tile
    @last_wall_tile = wall_tile

    -- cancel the jump
    if @jumping
      @seqs\remove @jumping
      @jumping = false

    -- cancel attack
    @end_attack!

    @wall_running = @seqs\add S "wall run", ->
      @wall_run_up_key = @facing
      wait 0.5
      @end_wall_run!


  end_wall_run: =>
    if @wall_running
      @seqs\remove @wall_running
      @wall_running = false

    @velocity[2] = math.max 0, @velocity[2]

  position_attack_box: =>
    return unless @attack_box
    if @stab_attacking
      @attack_box.x = @x - 1
      @attack_box.y = @y + 10
    else
      dist = 5
      @attack_box.y = @y + (@h - @attack_box.h) / 2

      if @facing == "left"
        @attack_box.x = @x - @attack_box.w - 5
      else
        @attack_box.x = @x + @w + 5

  attack: (downward) =>
    return if @attacking
    return unless @can_attack

    if downward
      @down_attack!
    else
      @horizontal_attack!

  down_attack: =>
    @stab_attacking = @facing
    @attacking = @seqs\add S "stab attack", ->
      wait 0.08 * 2

      @attack_box = Box 0, 0, @w + 2, 15
      @position_attack_box!
      @can_attack = false

      wait_until -> @on_ground or @wall_running
      @end_attack!

  horizontal_attack: =>
    @attacking = @seqs\add S "attack", ->
      wait 0.08 * 1

      @attack_box = Box 0, 0, 15, 10
      @position_attack_box!

      wait 0.08 * 1

      @attack_box = nil

      wait 0.08 * 2
      @end_attack!

  end_attack: =>
    return unless @attacking

    @seqs\remove @attacking
    @attack_box = nil
    @attacking = false
    @stab_attacking = false

  ledge_jump: (dx, dy) =>
    return if @jumping
    return unless @ledge_grabbing
    is_left = @ledge_grabbing.is_left

    @ledge_grabbing = false
    @jumping = @seqs\add S "ledge jump", ->
      -- pressing down or nothing, just drop to the ground
      vx, vy = if dx == 0 and dy > 0
        0,0
      elseif dx < 0 and is_left
        vx = -@jump_power / 2
        vy = -@jump_power
      elseif dx > 1 and not is_left
        vx = @jump_power / 2
        vy = -@jump_power
      else
        vx = 0
        vy = -@jump_power

      @can_wall_jump = false

      @velocity[1] = vx
      @velocity[2] = vy

      wait 0.1
      @jumping = false

  jump: =>
    return if @jumping
    return unless @on_ground or @wall_running

    @jumping = @seqs\add S "ground jump", ->
      vx, vy = if @wall_running
        @end_wall_run!
        @slow_movement_for 0.3

        if @wall_run_up_key == "left"
          100, -@jump_power
        else
          -100, -@jump_power
      else
        0, -@jump_power

      @can_wall_jump = false

      @velocity[1] = vx
      @velocity[2] = vy

      wait 0.1
      @jumping = false

  slow_movement_for: (duration) =>
    if @_dampen_seq
      @seqs\remove @_dampen_seq

    @_dampen_seq = @seqs\add S "dampen", ->
      @dampen_movement = 0
      tween @, duration, dampen_movement: 1

  looking_at: (viewport) =>
    cx, cy = @center!
    if @facing == "left"
      cx - 20, cy
    else
      cx + 20, cy

  take_hit: (world, thing) =>
    return if @taking_hit
    @end_wall_run!
    @end_attack!
    hit_power = 150

    if thing.is_bullet
      thing\take_hit world, @

    @taking_hit = @seqs\add S "take hit", ->
      @effects\add ShakeEffect 0.2
      @world.viewport\shake!
      @world.particles\add BloodEmitter @world, @center!

      -- get center to center vec
      vx, vy = unpack (Vec2d(@center!) - Vec2d(thing\center!))\normalized! * hit_power
      @velocity[1] = vx
      @velocity[2] = vy / 2

      wait 0.2
      @taking_hit = false

  after_hit: (world, thing) =>
    if @stab_attacking
      @end_attack!
      @velocity[2] = -100

{ :Player }
