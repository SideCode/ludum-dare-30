
class LedgeZone extends Box
  w: 6
  h: 6

  new: (@tile, @tid, @is_left) =>
    x = @tile.x
    y = @tile.y

    unless @is_left
      x += @tile.w

    half = @w / 2
    super x - half, y - half

class PlatformMap extends TileMap
  -- move idx in x,y axis while staying inside boundgs
  move_idx: (idx, dx, dy) =>
    row = floor (idx - 1) / @width
    col = floor (idx - 1) % @width

    col += dx
    if col >= @width or col < 0
      return nil

    row += dy
    if row >= @height or row < 0
      return nil

    row * @width + col + 1

  -- there are two kinds of ledges, left and right
  -- checks for either
  is_ledge_tile: (idx) =>
    solid = @layers[@solid_layer]
    return unless solid[idx]

    local ledge_left, ledge_right

    above = @move_idx(idx, 0, -1)
    if not above or solid[above]
      return -- nope

    -- check left
    a,b,c = @move_idx(idx, -1, 0), @move_idx(idx, -1, -1), @move_idx(idx, -1, 1)
    if a and b and c
      if not solid[a] and not solid[b] and not solid[c]
        ledge_left = true

    -- check right
    a,b,c = @move_idx(idx, 1, 0), @move_idx(idx, 1, -1), @move_idx(idx, 1, 1)
    if a and b and c
      if not solid[a] and not solid[b] and not solid[c]
        ledge_right = true

    ledge_left, ledge_right

  find_ledge_zones: (zone_size=6) =>
    solid = @layers[@solid_layer]
    grid = UniformGrid!

    half = zone_size / 2

    for idx, t in pairs solid
      left, right = @is_ledge_tile idx

      if left
        grid\add LedgeZone t, idx, true

      if right
        grid\add LedgeZone t, idx, false

    grid

  -- takes the 1 indexed idx
  is_wall_tile: (idx) =>
    solid = @layers[@solid_layer]
    return false unless solid[idx]

    open_left, open_right, is_wall = false, false, false

    -- there are two kinds of walls, left and right
    if idx % @width != 1 -- check to the left
      unless solid[idx - 1]
        is_wall = true
        open_left = true

    if idx % @width != 0 -- check to the right
      unless solid[idx + 1]
        is_wall = true
        open_right = true

    is_wall, open_left, open_right

  pt_to_idx: (x,y) =>
    col = floor x / @cell_size
    row = floor y / @cell_size
    col + @width * row + 1 -- 1 indexed

  -- gets the bottom most tile for a wall, used to uniquely identify walls
  get_wall_root: (x, y) =>
    idx = @pt_to_idx x, y
    solid = @layers[@solid_layer]

    root = nil
    while @is_wall_tile idx
      root = solid[idx]
      idx += @width
      break if idx > @count

    root

  -- get a box that covers all tiles that make up a floor at the current tile
  get_floor_range: (x,y) =>
    idx = @pt_to_idx x, y
    solid = @layers[@solid_layer]
    return nil unless solid[idx]
    above = @move_idx idx, 0, -1
    return nil if not above or solid[above]

    -- go left
    left_idx = idx
    while true
      moved = @move_idx left_idx, -1, 0
      break unless moved and solid[moved]
      above = @move_idx moved, 0, -1
      break if not above or solid[above]

      left_idx = moved

    -- go right
    right_idx = idx
    while true
      moved = @move_idx right_idx, 1, 0
      break unless moved and solid[moved]
      above = @move_idx moved, 0, -1
      break if not above or solid[above]

      right_idx = moved

    with Box 0,0,0,0
      \add_box solid[left_idx]
      \add_box solid[right_idx]

class World
  gravity: Vec2d 0, 500

  new: (@game, map_name="maps.dev") =>
    @viewport = EffectViewport scale: GAME_CONFIG.scale

    @entities = DrawList!
    @collider = UniformGrid!

    import Lilguy, Gunguy from require "enemies"
    enemies = {Lilguy, Gunguy}
    count = 0

    @map = PlatformMap\from_tiled map_name, {
      object: (o) ->
        switch o.name
          when "spawn"
            @spawn_x = o.x
            @spawn_y = o.y
          when "enemy"
            cls = enemies[count % #enemies + 1]
            count += 1

            @entities\add cls o.x, o.y
    }

    @map_box = @map\to_box!
    @particles = DrawList!
    @ledge_zones = @map\find_ledge_zones!


  add_player: (player) =>
    error "there is already a player" if @player
    @player = player

    assert @spawn_x, "map does not have spawn"

    @player.x, @player.y = @spawn_x, @spawn_y
    @entities\add @player

  remove_player: =>
    with @player
      @entities\remove @player
      @player = nil

  collides: (thing) =>
    return true unless @map_box\contains_box thing
    @map\collides thing

  collides_pt: (x,y) =>
    return true unless @map_box\touches_pt x,y
    @map\collides_pt x,y

  draw: =>
    @viewport\apply!

    COLOR\push 222,84,84, 155
    @map_box\draw!
    COLOR\pop!

    @map\draw @viewport
    @entities\draw!
    @particles\draw!

    if DEBUG
      COLOR\pusha 60
      @ledge_zones\draw!
      COLOR\pop!

    @viewport\pop!

  update: (dt) =>
    @entities\update dt, @
    @particles\update dt, @

    @collider\clear!
    for e in *@entities
      continue unless e.alive
      continue unless e.w -- is a box
      @collider\add e

    @viewport\update dt

    return unless @player

    -- @viewport\center_on @player, @world.map_box, dt
    @viewport\center_on @player, nil, dt

    if @player.attack_box
      for thing in *@collider\get_touching @player.attack_box
        if thing.take_hit
          thing\take_hit @, @player

    -- see if player is hit by any enemies
    for thing in *@collider\get_touching @player
      continue if thing.dying
      continue if thing.taking_hit

      @player\take_hit @, thing

{ :World }
