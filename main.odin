package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import k2 "karl2d"

main :: proc() {
	init()
	for step() {}
	shutdown()
}

Entity_Kind :: enum {
	Ship,
	Bullet,
	Explosion,
}

Entity :: struct {
	alive:                    bool,
	kind:                     Entity_Kind,
	player_id:                int,
	position:                 [2]f32,
	velocity:                 [2]f32,
	engine_control:           [2]f32,
	sprite_sheet:             []Sprite_Frame,
	sprite_animated:          bool,
	sprite_frame_current:     int,
	sprite_frame_duration:    f32,
	sprite_frame_ttl:         f32,
	ship_gun_cooldown:        f32,
	ship_hitpoints:           int,
	ship_time_to_respawn:     f32,
	ship_time_beyond_screen:  f32,
	time_to_live:             f32,
	explosion_fade_duration:  f32,
	cpu2_frames_since_active: int,
	cpu2_gun_decision:        bool,
	cpu3_time_since_switch:   f32,
}

PLAYER_COUNT :: 4
PLAYGROUND_SIZE :: 720.0
SUN_RADIUS :: 36.0
SHIP_RADIUS :: 99.0 / 8.0
SHIP_HP_RADIUS :: 5.0
STARTING_RADIUS :: 180.0
STARTING_VELOCITY :: 90.0
GRAVITY_STRENGTH :: STARTING_VELOCITY * STARTING_VELOCITY * STARTING_RADIUS

SHIP_ENGINE_POWER_FORWARD :: 20.0
SHIP_ENGINE_POWER_BACK :: 20.0
SHIP_ENGINE_POWER_SIDE :: 15.0
SHIP_MAX_HITPOINTS :: 3
SHIP_MAX_TIME_BEYOND_SCREEN :: 10.0

SHIP_GUN_COOLDOWN :: 0.3
SHIP_TIME_TO_RESPAWN :: 3.0

BULLET_MUZZLE_DISTANCE :: SHIP_RADIUS + 5
BULLET_MUZZLE_SPEED :: 180.0
BULLET_TTL :: 4.0

BULLET_EXPLOSION_RADIUS :: 48.0

SCORE_SUN_COLLISION :: -2
SCORE_SHIP_COLLISION :: -1
SCORE_HIT :: 1
SCORE_HIT_SELF :: 1
SCORE_GUN_KILL :: 1
SCORE_GUN_KILL_SELF :: -1

PLAYER_TRAJECTORY_PREDICTION_DT :: 1.0 / 64.0
PLAYER_TRAJECTORY_PREDICTION_STEPS :: 8
PLAYER_TRAJECTORY_PREDICTION_STRIDE :: 12

PLAYER_NAMES: [PLAYER_COUNT]string = {"Player", "CPU 1", "CPU 2", "CPU 3"}
SPRITESHEET_SUN_PERIOD :: 8.0
PLAYER_COLORS: [PLAYER_COUNT]k2.Color = {k2.BLUE, k2.GREEN, k2.RED, k2.ORANGE}

Possible_States :: enum {
	Main_Menu,
	In_Game,
}

current_state: Possible_States
sun_animation_time: f32
master_volume: f32

init :: proc() {
	k2.init(1280, 720, "Korableke 2", {window_mode = .Windowed_Resizable})
	sun_animation_time = 0
	master_volume = 0.25
	init_assets()
	init_game_state()
}

screen_size: [2]f32
screen_center: [2]f32
screen_scale: f32

score_table: [PLAYER_COUNT]int
game_time_remaining: f32

init_game_state :: proc() {
	entity_reinit_all()
	current_state = .In_Game
	score_table = {}
	game_time_remaining = 180
	for i in 0 ..< PLAYER_COUNT {
		ship := entity_new()
		ship.kind = .Ship
		ship.player_id = i
		ship.sprite_sheet = SPRITES_SHIPS[:]
		ship.sprite_frame_current = i
		ship.cpu2_frames_since_active = i - 1
		ship_respawn(ship, math.TAU * f32(i) / f32(PLAYER_COUNT))
	}
	entity_commit()
}

do_physics_step :: proc(entity: ^Entity, dt: f32) {
	if entity.kind == .Explosion {
		entity.position += dt * entity.velocity
		return
	}
	sun_dist := linalg.length(entity.position)
	vel_mag := linalg.length(entity.velocity)
	forward := linalg.normalize0(entity.velocity)
	right := [2]f32{-forward.y, forward.x}
	acc := -GRAVITY_STRENGTH * entity.position / sun_dist / sun_dist / sun_dist
	engine_power := entity.engine_control
	engine_power.x = clamp(engine_power.x, -1, 1) * SHIP_ENGINE_POWER_SIDE
	engine_power.y = clamp(engine_power.y, -1, 1)
	if engine_power.y >= 0 {
		engine_power.y *= SHIP_ENGINE_POWER_FORWARD
	} else {
		engine_power.y *= SHIP_ENGINE_POWER_BACK
		engine_power.y = max(engine_power.y, -vel_mag / dt)
	}
	acc += engine_power.x * right
	acc += engine_power.y * forward
	entity.velocity += dt * acc
	entity.position += dt * entity.velocity
}

bullet_spawn_data :: proc(ship: Entity) -> (bullet: Entity) {
	forward := linalg.normalize0(ship.velocity)
	bullet.alive = true
	bullet.kind = .Bullet
	bullet.player_id = ship.player_id
	bullet.position = ship.position + BULLET_MUZZLE_DISTANCE * forward
	bullet.velocity = ship.velocity + BULLET_MUZZLE_SPEED * forward
	bullet.engine_control = 0
	bullet.time_to_live = BULLET_TTL
	bullet.sprite_sheet = SPRITES_BULLETS[:]
	switch ship.player_id {
	case 0:
		bullet.sprite_frame_current = rand.int_range(0, 2)
	case 1:
		bullet.sprite_frame_current = rand.int_range(2, 4)
	case 2, 3:
		bullet.sprite_frame_current = rand.int_range(4, 6)
	}
	return
}

ship_shoot_bullet :: proc(ship: ^Entity) {
	if ship.ship_gun_cooldown > 0 do return
	if ship.ship_time_to_respawn > 0 do return
	ship.ship_gun_cooldown = SHIP_GUN_COOLDOWN
	bullet := entity_new()
	bullet^ = bullet_spawn_data(ship^)
	sound := rand.choice(SOUNDS_GUN[:])
	k2.set_sound_volume(sound, master_volume)
	k2.play_sound(sound)
}

ship_respawn :: proc(ship: ^Entity, phase: f32) {
	sin, cos := math.sincos(phase)
	ship.position = STARTING_RADIUS * {cos, sin}
	ship.velocity = STARTING_VELOCITY * {-sin, cos}
	ship.engine_control = 0
	ship.ship_hitpoints = SHIP_MAX_HITPOINTS
}

explosion_spawn :: proc(entity: Entity) {
	explosion := entity_new()
	explosion.kind = .Explosion
	explosion.player_id = -1
	explosion.position = entity.position
	#partial switch entity.kind {
	case .Ship:
		explosion.velocity = entity.velocity
		explosion.time_to_live = rand.float32_range(1.75, 2.25)
		explosion.explosion_fade_duration = explosion.time_to_live
		explosion.sprite_sheet = rand.choice(SPRITESHEET_SHIP_EXPLOSION[:])[:]
	case .Bullet:
		explosion.time_to_live = rand.float32_range(0.25, 0.375)
		explosion.explosion_fade_duration = 0.0625
		explosion.sprite_sheet = SPRITESHEET_BULLET_EXPLOSION[entity.player_id]
	}
	explosion.sprite_animated = true
	explosion.sprite_frame_duration = explosion.time_to_live / f32(len(explosion.sprite_sheet))
	explosion.sprite_frame_ttl = explosion.sprite_frame_duration
}

ship_die :: proc(ship: ^Entity) {
	explosion_spawn(ship^)
	phase := rand.float32_range(-math.PI, math.PI)
	ship_respawn(ship, phase)
	ship.ship_time_to_respawn = SHIP_TIME_TO_RESPAWN
}

draw_sprite :: proc(sprite: Sprite_Frame, center: [2]f32, rotation: f32 = 0, tint := k2.WHITE) {
	texture_size := [2]f32{f32(sprite.texture.width), f32(sprite.texture.height)}
	texture_size_scaled := screen_scale * sprite.scale * texture_size
	k2.draw_texture_fit(
		sprite.texture,
		{
			x = f32(sprite.src_rect.x),
			y = f32(sprite.src_rect.y),
			w = f32(sprite.src_rect.z),
			h = f32(sprite.src_rect.w),
		},
		{
			x = screen_center.x + screen_scale * center.x,
			y = screen_center.y + screen_scale * center.y,
			w = texture_size_scaled.x,
			h = texture_size_scaled.y,
		},
		texture_size_scaled / 2,
		rotation,
		tint,
	)
}

step :: proc() -> bool {
	if !k2.update() do return false
	k2.clear(k2.BLACK)
	if k2.key_went_down(.R) do init_game_state()
	dt := k2.get_frame_time()
	// In case window didn't receive events for a long time,
	// like when being dragged or resized
	dt = min(0.05, dt)
	screen_width := k2.get_screen_width()
	screen_height := k2.get_screen_height()
	screen_size = {f32(screen_width), f32(screen_height)}
	screen_center = screen_size / 2
	screen_min_size := min(screen_size.x, screen_size.y)
	screen_scale = screen_min_size / PLAYGROUND_SIZE

	background_integer_scaling := int(
		math.ceil(
			max(
				screen_size.x / f32(TEXTURE_BACKGROUND.width),
				screen_size.y / f32(TEXTURE_BACKGROUND.height),
				1,
			),
		),
	)
	k2.draw_texture_fit(
		TEXTURE_BACKGROUND,
		{w = f32(TEXTURE_BACKGROUND.width), h = f32(TEXTURE_BACKGROUND.height)},
		{
			x = screen_center.x - f32(background_integer_scaling * TEXTURE_BACKGROUND.width) / 2,
			y = screen_center.y - f32(background_integer_scaling * TEXTURE_BACKGROUND.height) / 2,
			w = f32(background_integer_scaling * TEXTURE_BACKGROUND.width),
			h = f32(background_integer_scaling * TEXTURE_BACKGROUND.height),
		},
	)

	game_time_remaining -= dt
	if game_time_remaining < 0 {
		game_time_remaining = 0
		for &ship, ship_id in entities {
			// Ships explode immediately, bullets --- one at a time
			if !ship.alive do continue
			if ship.kind != .Ship do continue
			explosion_spawn(ship)
			entity_free(ship_id)
		}
	}

	// Controls + physics
	for &entity, entity_id in entities {
		if !entity.alive do continue
		switch entity.kind {
		case .Ship:
			entity.ship_gun_cooldown = max(0, entity.ship_gun_cooldown - dt)
			entity.ship_time_to_respawn = max(0, entity.ship_time_to_respawn - dt)
			if linalg.dot(entity.position, entity.velocity) > 0 {
				distance_from_sun := linalg.length(entity.position)
				if distance_from_sun > PLAYGROUND_SIZE / 2 {
					entity.ship_time_beyond_screen += dt
				}
			} else {
				entity.ship_time_beyond_screen = 0
			}
			switch entity.player_id {
			case 0:
				strategy_player(&entity, entity_id)
			case 1:
				strategy_cpu2(&entity, entity_id)
			case 2:
				strategy_cpu2(&entity, entity_id)
			case 3:
				strategy_cpu2(&entity, entity_id)
			}
		case .Bullet, .Explosion:
			entity.time_to_live -= dt
			if entity.time_to_live <= 0 {
				entity_free(entity_id)
				continue
			}
		}
		do_physics_step(&entity, dt)
	}
	entity_commit()

	// Collisions
	for &ship, ship_id in entities {
		if !ship.alive do continue
		if ship.kind != .Ship do continue
		if ship.ship_time_to_respawn > 0 do continue

		if linalg.length(ship.position) < SUN_RADIUS {
			score_table[ship.player_id] += SCORE_SUN_COLLISION
			ship_die(&ship)
			continue
		}

		if ship.ship_time_beyond_screen > SHIP_MAX_TIME_BEYOND_SCREEN {
			ship_die(&ship)
		}

		for bullet, bullet_id in entities {
			if ship_id == bullet_id do continue
			if bullet.kind != .Bullet do continue
			distance := linalg.length(ship.position - bullet.position)
			if distance > SHIP_RADIUS do continue

			ship.ship_hitpoints -= 1
			if ship.player_id == bullet.player_id {
				score_table[bullet.player_id] += SCORE_HIT_SELF
				if ship.ship_hitpoints <= 0 {
					score_table[bullet.player_id] += SCORE_GUN_KILL_SELF
				}
			} else {
				score_table[bullet.player_id] += SCORE_HIT
				if ship.ship_hitpoints <= 0 {
					score_table[bullet.player_id] += SCORE_GUN_KILL
				}
			}

			explosion_spawn(bullet)
			entity_free(bullet_id)
			if ship.ship_hitpoints <= 0 {
				ship_die(&ship)
				break
			}
		}
	}

	// Ship to ship collisions
	for &ship, ship_id in entities {
		if !ship.alive do continue
		if ship.ship_time_to_respawn > 0 do continue
		if ship.kind != .Ship do continue

		for &other_ship, other_ship_id in entities {
			if ship_id == other_ship_id do continue
			if !other_ship.alive do continue
			if other_ship.kind != .Ship do continue
			if other_ship.ship_time_to_respawn > 0 do continue
			distance := linalg.length(ship.position - other_ship.position)
			if distance > 2 * SHIP_RADIUS do continue

			score_table[ship.player_id] += SCORE_HIT * other_ship.ship_hitpoints
			score_table[other_ship.player_id] += SCORE_HIT * ship.ship_hitpoints
			score_table[ship.player_id] += SCORE_SHIP_COLLISION * ship.ship_hitpoints
			score_table[other_ship.player_id] += SCORE_SHIP_COLLISION * other_ship.ship_hitpoints

			ship_die(&ship)
			ship_die(&other_ship)
			break
		}
	}
	entity_commit()

	// Render
	for &entity in entities {
		if !entity.alive do continue

		if entity.sprite_animated {
			entity.sprite_frame_ttl -= dt
			if entity.sprite_frame_ttl < 0 {
				entity.sprite_frame_current =
					(entity.sprite_frame_current + 1) % len(entity.sprite_sheet)
				entity.sprite_frame_ttl = entity.sprite_frame_duration
			}
		}

		switch entity.kind {
		case .Ship:
			sprite := entity.sprite_sheet[entity.sprite_frame_current]
			forward_angle := math.atan2(entity.velocity.x, -entity.velocity.y)
			tint := k2.WHITE
			if entity.ship_time_to_respawn > 0 {
				blink_stage := int(4 * entity.ship_time_to_respawn)
				if blink_stage % 2 == 0 {
					tint.w = 63
				} else {
					tint.w = 191
				}
			} else {
				if entity.ship_time_beyond_screen > 0 {
					coef := 1 - entity.ship_time_beyond_screen / SHIP_MAX_TIME_BEYOND_SCREEN
					tint.yz = u8(255 * clamp(coef, 0, 1))
				}
				for i_hp in 0 ..< SHIP_MAX_HITPOINTS {
					offset := [2]f32 {
						f32(i_hp - SHIP_MAX_HITPOINTS / 2) * 1.5 * SHIP_HP_RADIUS,
						SHIP_RADIUS + SHIP_HP_RADIUS,
					}
					screen_pos := screen_center + screen_scale * (entity.position + offset)
					if i_hp < entity.ship_hitpoints {
						k2.draw_circle(screen_pos, SHIP_HP_RADIUS, PLAYER_COLORS[entity.player_id])
					} else {
						k2.draw_circle_outline(
							screen_pos,
							SHIP_HP_RADIUS,
							2,
							PLAYER_COLORS[entity.player_id],
						)
					}
				}
			}
			draw_sprite(sprite, entity.position, forward_angle, tint)

		case .Bullet:
			sprite := entity.sprite_sheet[entity.sprite_frame_current]
			forward_angle := math.atan2(entity.velocity.x, -entity.velocity.y)
			draw_sprite(sprite, entity.position, forward_angle)
		case .Explosion:
			sprite := entity.sprite_sheet[entity.sprite_frame_current]
			tint := k2.WHITE
			tint.w = u8(255 * clamp(entity.time_to_live / entity.explosion_fade_duration, 0, 1))
			draw_sprite(sprite, entity.position, 0, tint)
		}

		if entity.kind == .Ship && entity.player_id == 0 {
			prediction_copy := entity
			prediction_copy.engine_control = 0
			for j in 1 ..= PLAYER_TRAJECTORY_PREDICTION_STEPS {
				for _ in 0 ..< PLAYER_TRAJECTORY_PREDICTION_STRIDE {
					do_physics_step(&prediction_copy, PLAYER_TRAJECTORY_PREDICTION_DT)
				}
				radius := 7 / f32(j + 1)
				forward := linalg.normalize0(prediction_copy.velocity)
				right := [2]f32{-forward.y, forward.x}
				vertices: [3][2]f32
				// sin(120 deg) = sin(60 deg) = sqrt(3)/2
				// cos(120 deg) = -cos(60 deg) = -sin(30 deg) = -1/2
				offx := radius / 2
				offy := math.SQRT_THREE / 2 * radius
				vertices[0] = prediction_copy.position + radius * forward
				vertices[1] = prediction_copy.position - offx * forward + offy * right
				vertices[2] = prediction_copy.position - offx * forward - offy * right
				for &v in vertices do v = screen_center + screen_scale * v
				k2.draw_triangle(vertices, PLAYER_COLORS[entity.player_id])
			}
		}
	}

	{
		sun_animation_time += dt
		for sun_animation_time > SPRITESHEET_SUN_PERIOD {
			sun_animation_time -= SPRITESHEET_SUN_PERIOD
		}
		sprite_id := int(sun_animation_time / SPRITESHEET_SUN_PERIOD * SPRITESHEET_SUN_COUNT_TOTAL)
		sprite := SPRITESHEET_SUN[sprite_id]
		draw_sprite(sprite, 0)
	}

	k2.draw_text(fmt.tprintf("FPS: %f", 1 / dt), {18, 18}, 36, k2.WHITE)
	game_time_format := game_time_remaining < 10 ? "Remaining time: %.2f" : "Remaining time: %.1f"
	game_time_text := fmt.tprintf(game_time_format, game_time_remaining)
	k2.draw_text(game_time_text, {18, 54}, 36, k2.WHITE)
	for i in 0 ..< PLAYER_COUNT {
		k2.draw_text(
			fmt.tprintf("%s:\t%d", PLAYER_NAMES[i], score_table[i]),
			{18, 108 + 36 * f32(i)},
			36,
			k2.WHITE,
		)
	}

	k2.present()
	free_all(context.temp_allocator)
	return true
}

shutdown :: proc() {
	k2.shutdown()
}

