# frozen_string_literal: true

FPS = 60
HIGH_SCORE_FILE = 'high-score.txt'

def tick(args)
  handle_background_music(args)

  args.state.scene ||= 'title'

  send("#{args.state.scene}_tick", args)
end

def handle_background_music(args)
  args.audio[:music] = { input: 'sounds/flight.ogg', looping: true } if args.state.tick_count == 1

  # FIXME: Does not work
  # if args.inputs.mouse.has_focus && args.audio[:music]&.paused
  #   args.audio[:music].paused = false
  # elsif !args.inputs.mouse.has_focus && !args.audio[:music].paused
  #   args.audio[:music].paused = true
  # end
end

def title_tick(args)
  args.state.background ||= {
    x: 0,
    y: 0,
    w: args.grid.w,
    h: args.grid.h,
    path: 'sprites/blue-sky.png'
  }

  if fire_input?(args)
    args.outputs.sounds << 'sounds/game-over.wav'
    args.state.scene = 'gameplay'
    return
  end

  args.outputs.sprites << args.state.background
  args.outputs.labels << title_labels(args)
end

def gameplay_tick(args)
  args.state.clouds ||= 20.times.map { spawn_cloud(args) }
  animate_clouds_movement(args)

  args.state.player ||= {
    x: 120,
    y: 280,
    w: 100,
    h: 80,
    speed: 12,
    path: 'sprites/misc/dragon-0.png'
  }
  animate_player(args)

  args.state.fireballs ||= []
  args.state.targets ||= 3.times.map { spawn_target(args) }
  args.state.score ||= 0
  args.state.timer ||= 30 * FPS

  args.state.timer -= 1

  if args.state.timer == 0
    args.audio[:music].paused = true
    args.outputs.sounds << 'sounds/game-over.wav'
  end

  if args.state.timer < 0
    game_over_tick(args)
    return
  end

  handle_player_movement(args)
  handle_fireballs(args)

  args.outputs.sprites << [
    args.state.background,
    args.state.clouds,
    args.state.player,
    args.state.fireballs,
    args.state.targets
  ]

  args.outputs.labels << gameplay_labels(args)
end

def game_over_tick(args)
  high_score, achived_at = get_high_score(args)

  args.outputs.sprites << args.state.background
  args.outputs.labels << game_over_labels(args, high_score: high_score, achived_at: achived_at)

  $gtk.reset if args.state.timer < -30 && fire_input?(args)
end

def title_labels(args)
  [
    {
      x: 40,
      y: args.grid.h - 40,
      text: 'Target Practice',
      size_enum: 6
    },
    {
      x: 40,
      y: args.grid.h - 88,
      text: 'Hit the targets!'
    },
    {
      x: 40,
      y: args.grid.h - 120,
      text: 'by zzaakiirr'
    },
    {
      x: 40,
      y: 120,
      text: 'Arrows or WASD to move | Z or J to fire | gamepad works too'
    },
    {
      x: 40,
      y: 80,
      text: 'Fire to start',
      size_enum: 2
    }
  ]
end

def animate_player(args)
  player_sprite_index = 0.frame_index(count: 6, hold_for: 8, repeat: true)
  args.state.player.path = "sprites/misc/dragon-#{player_sprite_index}.png"
end

def animate_clouds_movement(args)
  args.state.clouds.each_with_index do |cloud, i|
    cloud.x = 0 if cloud.x > args.grid.w + cloud.w
    cloud.x += cloud.speed + i / 20
  end
end

def handle_fireballs(args)
  shoot_fireball(args) if fire_input?(args)

  args.state.fireballs.each do |fireball|
    fireball.x += args.state.player.speed + 2

    if fireball.x > args.grid.w
      fireball.dead = true
      next
    end

    args.state.targets.each do |target|
      if args.geometry.intersect_rect?(target, fireball)
        handle_target_hit_by_fireball(args, target: target, fireball: fireball)
      end
    end
  end

  args.state.targets.reject!(&:dead)
  args.state.fireballs.reject!(&:dead)
end

def shoot_fireball(args)
  args.outputs.sounds << 'sounds/fireball.wav'

  args.state.fireballs << {
    x: args.state.player.x + args.state.player.w - 12,
    y: args.state.player.y + 10,
    w: 32,
    h: 32,
    path: 'sprites/fireball.png'
  }
end

def handle_target_hit_by_fireball(args, target:, fireball:)
  args.outputs.sounds << 'sounds/target.wav'

  target.dead = true
  fireball.dead = true

  args.state.score += 1
  args.state.targets << spawn_target(args)
end

def gameplay_labels(args)
  [
    {
      x: 40,
      y: args.grid.h - 40,
      text: "Score: #{args.state.score}",
      size_enum: 4
    },
    {
      x: args.grid.w - 40,
      y: args.grid.h - 40,
      text: "Time Left: #{(args.state.timer / FPS).round}",
      size_enum: 2,
      alignment_enum: 2
    }
  ]
end

def get_high_score(args)
  high_score, achived_at = args.gtk.read_file(HIGH_SCORE_FILE).to_s.split(',')
  high_score = high_score.to_i

  args.state.timer -= 1

  if !args.state.saved_high_score && args.state.score > high_score.to_i
    args.gtk.write_file(HIGH_SCORE_FILE, "#{args.state.score}, #{Time.now}")
    args.state.saved_high_score = true
  end

  [high_score, achived_at]
end

def game_over_labels(args, high_score: 0, achived_at: nil)
  [
    {
      x: 40,
      y: args.grid.h - 40,
      text: 'Game Over!',
      size_enum: 10
    },
    {
      x: 40,
      y: args.grid.h - 90,
      text: "Score: #{args.state.score}",
      size_enum: 4
    },
    {
      x: 260,
      y: args.grid.h - 90,
      text: (args.state.score > high_score ? 'New high-score!' : "Score to beat: #{high_score} (#{achived_at})"),
      size_enum: 3
    },
    {
      x: 40,
      y: args.grid.h - 132,
      text: 'Fire to restart',
      size_enum: 2
    }
  ]
end

def spawn_target(args)
  size = 64
  {
    x: [rand(args.grid.w * 0.4) + args.grid.w * 0.6, args.grid.w - size * 2].min,
    y: rand(args.grid.h - size * 2) + size,
    w: size,
    h: size,
    path: 'sprites/target.png'
  }
end

def spawn_cloud(args)
  width = 64
  height = 39
  {
    x: rand(args.grid.w * 0.4),
    y: rand(args.grid.h - height * 2) + height,
    w: width,
    h: height,
    speed: 1,
    path: 'sprites/cloud.png'
  }
end

def fire_input?(args)
  args.inputs.keyboard.key_down.z || args.inputs.keyboard.key_down.j || args.inputs.controller_one.key_down.a
end

def handle_player_movement(args)
  if args.inputs.left
    args.state.player.x -= args.state.player.speed
    speed_up_player_animation(args)
  elsif args.inputs.right
    args.state.player.x += args.state.player.speed
    speed_up_player_animation(args)
  end

  if args.inputs.up
    args.state.player.y += args.state.player.speed
    speed_up_player_animation(args)
  elsif args.inputs.down
    args.state.player.y -= args.state.player.speed
    speed_up_player_animation(args)
  end

  if args.state.player.x + args.state.player.w > args.grid.w
    args.state.player.x = args.grid.w - args.state.player.w
  end

  if args.state.player.x < 0
    args.state.player.x = 0
  end

  if args.state.player.y + args.state.player.h > args.grid.h
    args.state.player.y = args.grid.h - args.state.player.h
  end

  if args.state.player.y < 0
    args.state.player.y = 0
  end
end

def speed_up_player_animation(args)
  repeat_index = args.state.player.path.split('/').delete('^0-9').to_i
  player_sprite_index = 0.frame_index(count: 6, hold_for: 4, repeat: true, repeat_index: repeat_index)
  args.state.player.path = "sprites/misc/dragon-#{player_sprite_index}.png"
end

$gtk.reset
