require "lovekit.all"

-- if pcall(-> require"inotify")
--   require "lovekit.reloader"

{graphics: g} = love

import TitleScreen, GameOverScreen, StageComplete from require "screens"
import Game from require "game"

export DEBUG = false

load_font = (img, chars)->
  font_image = imgfy img
  g.newImageFont font_image.tex, chars

love.load = ->
  fonts = {
    default: load_font "images/font1.png", [[ ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~!"#$%&'()*+,-./0123456789:;<=>?]]
    number_font: load_font "images/number_font.png", [[0123456789:]]
  }

  g.setFont fonts.default
  g.setBackgroundColor 13,15,12

  export AUDIO = Audio "sounds"
  AUDIO\preload {
    "step"
    "grab"
    "land"
    "hurt_enemy"
    "jump"
    "enemy_die"
    "energy_appear"
    "player_die"
    "player_attack"
    "level_complete"
    "level_fail"
    "clink"
    "confirm"
    "no_hurt"
    "door_ready"
  }

  export FONTS = fonts
  export CONTROLLER = Controller GAME_CONFIG.keys

  init = if DEBUG
    Game!
  else
    TitleScreen Game!

  export DISPATCHER = Dispatcher init

  DISPATCHER.default_transition = FadeTransition
  DISPATCHER\bind love

