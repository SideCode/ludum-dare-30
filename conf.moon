export GAME_CONFIG = {
  scale: 2
  keys: {
    confirm: { "x", " " }
    cancel: "c"

    attack: { "c", "return" }
    jump: { "x", " " }

    up: "up"
    down: "down"
    left: "left"
    right: "right"
  }
}

love.conf = (t) ->
  t.window.width = 420 * GAME_CONFIG.scale
  t.window.height = 272 * GAME_CONFIG.scale

  t.title = "wallrun dot love"
  t.author = "leafo + i.i"
