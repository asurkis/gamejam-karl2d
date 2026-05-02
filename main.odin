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
	alive:                  bool,
	kind:                   Entity_Kind,
	player_id:              int,
	position:               [2]f32,
	velocity:               [2]f32,
	engine_control:         [2]f32,
	ship_gun_cooldown:      f32,
	ship_hitpoints:         int,
	ship_time_to_respawn:   f32,
	time_to_live:           f32,
	bullet_sprite_variant:  int,
	cpu3_time_since_switch: f32,
}

PLAYER_COUNT :: 4
PLAYGROUND_SIZE :: 720.0
SUN_VISIBLE_RADIUS :: 72.0
SUN_RADIUS :: 36.0
SHIP_RADIUS :: 99.0 / 8.0
SHIP_HP_RADIUS :: 5.0
STARTING_RADIUS :: 180.0
STARTING_VELOCITY :: 90.0
GRAVITY_STRENGTH :: STARTING_VELOCITY * STARTING_VELOCITY * STARTING_RADIUS

SHIP_ENGINE_POWER_FORWARD :: 20.0
SHIP_ENGINE_POWER_BACK :: 7.0
SHIP_ENGINE_POWER_SIDE :: 5.0
SHIP_MAX_HITPOINTS :: 3

SHIP_GUN_COOLDOWN :: 0.3
SHIP_TIME_TO_RESPAWN :: 3.0

BULLET_VISIBLE_RADIUS :: 10.0
BULLET_MUZZLE_DISTANCE :: SHIP_RADIUS + 5
BULLET_MUZZLE_SPEED :: 180.0
BULLET_TTL :: 4.0

EXPLOSION_DURATION :: 2.0

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
TEXTURE_DATA_BACKGROUND :: #load("./Green_Nebula_03-1024x1024.png")
SPRITESHEET_DATA_SUN :: #load("./2663172042.png")
SPRITESHEET_SUN_COUNT_X :: 8
SPRITESHEET_SUN_COUNT_Y :: 8
SPRITESHEET_SUN_COUNT_TOTAL :: SPRITESHEET_SUN_COUNT_X * SPRITESHEET_SUN_COUNT_Y
SPRITESHEET_SUN_PERIOD :: 8.0
SPRITE_DATA_SHIPS: [PLAYER_COUNT][]u8 = {
	#load("kenney_space-shooter-remastered/PNG/playerShip1_blue.png"),
	#load("kenney_space-shooter-remastered/PNG/playerShip1_green.png"),
	#load("kenney_space-shooter-remastered/PNG/playerShip1_red.png"),
	#load("kenney_space-shooter-remastered/PNG/playerShip1_orange.png"),
}
SPRITE_DATA_BULLETS: [][]u8 = {
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue01.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue07.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue16.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserGreen10.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserGreen11.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserGreen12.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserGreen13.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserRed01.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserRed06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserRed07.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserRed16.png"),
}
PLAYER_COLORS: [PLAYER_COUNT]k2.Color = {k2.BLUE, k2.GREEN, k2.RED, k2.ORANGE}
TEXTURE_BACKGROUND: k2.Texture
SPRITESHEET_SUN: k2.Texture
SPRITES_SHIPS: [PLAYER_COUNT]k2.Texture
SPRITES_BULLETS: [12]k2.Texture

sun_animation_time: f32

init :: proc() {
	k2.init(1280, 720, "Korableke 2", {window_mode = .Windowed_Resizable})
	TEXTURE_BACKGROUND = k2.load_texture_from_bytes(TEXTURE_DATA_BACKGROUND)
	SPRITESHEET_SUN = k2.load_texture_from_bytes(SPRITESHEET_DATA_SUN)
	for i in 0 ..< PLAYER_COUNT {
		SPRITES_SHIPS[i] = k2.load_texture_from_bytes(SPRITE_DATA_SHIPS[i])
	}
	for i in 0 ..< 12 {
		SPRITES_BULLETS[i] = k2.load_texture_from_bytes(SPRITE_DATA_BULLETS[i])
	}
	sun_animation_time = 0
	init_game_state()
}

score_table: [PLAYER_COUNT]int
game_time_remaining: f32
animation_ttl: f32

init_game_state :: proc() {
	entity_reinit_all()
	score_table = {}
	game_time_remaining = 180
	animation_ttl = 0
	for i in 0 ..< PLAYER_COUNT {
		ship, _ := entity_new()
		ship.player_id = i
		ship.kind = .Ship
		ship_respawn(ship, math.TAU * f32(i) / f32(PLAYER_COUNT))
	}
}

do_physics_step :: proc(entity: ^Entity, dt: f32) {
	sun_dist := linalg.length(entity.position)
	vel_mag := linalg.length(entity.velocity)
	forward := linalg.normalize0(entity.velocity)
	right := [2]f32{-forward.y, forward.x}
	acc := -GRAVITY_STRENGTH * entity.position / sun_dist / sun_dist / sun_dist
	gravity_tang := linalg.dot(acc, forward)
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

bullet_data_if_shot :: proc(ship: Entity) -> (bullet: Entity) {
	forward := linalg.normalize0(ship.velocity)
	bullet.alive = true
	bullet.kind = .Bullet
	bullet.player_id = ship.player_id
	bullet.position = ship.position + BULLET_MUZZLE_DISTANCE * forward
	bullet.velocity = ship.velocity + BULLET_MUZZLE_SPEED * forward
	bullet.engine_control = 0
	bullet.time_to_live = BULLET_TTL
	switch ship.player_id {
	case 0:
		bullet.bullet_sprite_variant = rand.int_range(0, 4)
	case 1:
		bullet.bullet_sprite_variant = rand.int_range(4, 8)
	case 2, 3:
		bullet.bullet_sprite_variant = rand.int_range(8, 12)
	}
	return
}

ship_shoot_bullet :: proc(ship: ^Entity) {
	if ship.ship_gun_cooldown > 0 do return
	if ship.ship_time_to_respawn > 0 do return
	ship.ship_gun_cooldown = SHIP_GUN_COOLDOWN
	bullet, _ := entity_new()
	bullet^ = bullet_data_if_shot(ship^)
}

ship_respawn :: proc(ship: ^Entity, phase: f32) {
	sin, cos := math.sincos(phase)
	ship.position = STARTING_RADIUS * {cos, sin}
	ship.velocity = STARTING_VELOCITY * {-sin, cos}
	ship.engine_control = 0
	ship.ship_hitpoints = SHIP_MAX_HITPOINTS
}

explosion_spawn :: proc(entity: ^Entity) {
	explosion, _ := entity_new()
	explosion.kind = .Explosion
	explosion.player_id = -1
	explosion.position = entity.position
	explosion.velocity = entity.velocity
	explosion.time_to_live = EXPLOSION_DURATION
}

ship_die :: proc(ship: ^Entity) {
	explosion_spawn(ship)
	phase := rand.float32_range(-math.PI, math.PI)
	ship_respawn(ship, phase)
	ship.ship_time_to_respawn = SHIP_TIME_TO_RESPAWN
}

step :: proc() -> bool {
	if !k2.update() do return false
	k2.clear(k2.DARK_BLUE)
	if k2.key_went_down(.R) do init_game_state()
	dt := k2.get_frame_time()
	// In case window didn't receive events for a long time,
	// like when being dragged or resized
	dt = min(0.05, dt)
	screen_width := k2.get_screen_width()
	screen_height := k2.get_screen_height()
	screen_size := [2]f32{f32(screen_width), f32(screen_height)}
	screen_center := screen_size / 2
	screen_min_size := min(screen_size.x, screen_size.y)
	scale := screen_min_size / PLAYGROUND_SIZE

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
			explosion_spawn(&ship)
			entity_free(ship_id)
		}
		animation_ttl -= dt
		if animation_ttl < 0 {
			animation_ttl = 1.0 / 32.0
			for &entity, entity_id in entities {
				if !entity.alive do continue
				if entity.kind == .Explosion do continue
				explosion_spawn(&entity)
				entity_free(entity_id)
				break
			}
		}
	}

	// Controls + physics
	for &entity, entity_id in entities {
		if !entity.alive do continue
		switch entity.kind {
		case .Ship:
			entity.ship_gun_cooldown = max(0, entity.ship_gun_cooldown - dt)
			entity.ship_time_to_respawn = max(0, entity.ship_time_to_respawn - dt)
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

		// if entity.kind == .Ship && entity.player_id == 0 {
		// 	forward := linalg.normalize0(entity.velocity)
		// 	right: [2]f32 = {-forward.y, forward.x}
		// 	k2.draw_line(
		// 		screen_center + scale * entity.position,
		// 		screen_center + scale * entity.position + 100 * forward,
		// 		3,
		// 		k2.RED,
		// 	)
		// 	k2.draw_line(
		// 		screen_center + scale * entity.position,
		// 		screen_center + scale * entity.position + 100 * right,
		// 		3,
		// 		k2.BLUE,
		// 	)
		// }
	}

	// Collisions
	for &ship, ship_id in entities {
		if !ship.alive do continue
		if ship.ship_time_to_respawn > 0 do continue
		if ship.kind != .Ship do continue

		if linalg.length(ship.position) < SUN_RADIUS {
			score_table[ship.player_id] += SCORE_SUN_COLLISION
			ship_die(&ship)
			continue
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

			if ship.ship_hitpoints <= 0 {
				ship_die(&ship)
			}
			entity_free(bullet_id)
			break
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
			score_table[ship.player_id] += SCORE_SHIP_COLLISION
			score_table[other_ship.player_id] += SCORE_SHIP_COLLISION

			ship_die(&ship)
			ship_die(&other_ship)
			break
		}
	}

	// Render
	for entity in entities {
		if !entity.alive do continue
		switch entity.kind {
		case .Ship:
			texture := SPRITES_SHIPS[entity.player_id]
			texture_size := [2]f32{f32(texture.width), f32(texture.height)}
			texture_scale := 2 * SHIP_RADIUS * scale / max(texture_size.x, texture_size.y)
			texture_size_scaled := texture_scale * texture_size
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
				for i_hp in 0 ..< SHIP_MAX_HITPOINTS {
					offset := [2]f32 {
						f32(i_hp - SHIP_MAX_HITPOINTS / 2) * 1.5 * SHIP_HP_RADIUS,
						SHIP_RADIUS + SHIP_HP_RADIUS,
					}
					screen_pos := screen_center + scale * (entity.position + offset)
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
			k2.draw_texture_fit(
				texture,
				source = {w = f32(texture.width), h = f32(texture.height)},
				dest = {
					x = screen_center.x + scale * entity.position.x,
					y = screen_center.y + scale * entity.position.y,
					w = texture_size_scaled.x,
					h = texture_size_scaled.y,
				},
				origin = texture_size_scaled / 2,
				rotation = forward_angle,
				tint = tint,
			)
		case .Bullet:
			texture := SPRITES_BULLETS[entity.bullet_sprite_variant]
			texture_size := [2]f32{f32(texture.width), f32(texture.height)}
			texture_scale :=
				2 * BULLET_VISIBLE_RADIUS * scale / max(texture_size.x, texture_size.y)
			texture_size_scaled := texture_scale * texture_size
			forward_angle := math.atan2(entity.velocity.x, -entity.velocity.y)
			k2.draw_texture_fit(
				texture,
				{w = texture_size.x, h = texture_size.y},
				{
					x = screen_center.x + scale * entity.position.x,
					y = screen_center.y + scale * entity.position.y,
					w = texture_size_scaled.x,
					h = texture_size_scaled.y,
				},
				texture_size_scaled / 2,
				forward_angle,
			)
		case .Explosion:
			color := k2.ORANGE
			color.w = u8(255 * clamp(entity.time_to_live / EXPLOSION_DURATION, 0, 1))
			k2.draw_circle(
				screen_center + scale * entity.position,
				90 - 30 * entity.time_to_live,
				color,
			)
		}

		if entity.kind == .Ship && entity.player_id == 0 {
			prediction_copy := entity
			prediction_copy.engine_control = 0
			for j in 1 ..= PLAYER_TRAJECTORY_PREDICTION_STEPS {
				for _ in 0 ..< PLAYER_TRAJECTORY_PREDICTION_STRIDE {
					do_physics_step(&prediction_copy, PLAYER_TRAJECTORY_PREDICTION_DT)
				}
				radius := 5 / f32(j)
				k2.draw_circle(
					screen_center + scale * prediction_copy.position,
					radius,
					PLAYER_COLORS[entity.player_id],
				)
			}
		}
	}

	{
		sun_animation_time += dt
		for sun_animation_time > SPRITESHEET_SUN_PERIOD {
			sun_animation_time -= SPRITESHEET_SUN_PERIOD
		}
		sprite_id := int(sun_animation_time / SPRITESHEET_SUN_PERIOD * SPRITESHEET_SUN_COUNT_TOTAL)
		sprite_row := sprite_id / SPRITESHEET_SUN_COUNT_X
		sprite_col := sprite_id % SPRITESHEET_SUN_COUNT_X
		sprite_size: [2]f32
		sprite_size.x = f32(SPRITESHEET_SUN.width) / SPRITESHEET_SUN_COUNT_X
		sprite_size.y = f32(SPRITESHEET_SUN.height) / SPRITESHEET_SUN_COUNT_Y
		sprite_scale := 2 * SUN_VISIBLE_RADIUS * scale / max(sprite_size.x, sprite_size.y)
		sprite_size_scaled := sprite_scale * sprite_size
		k2.draw_texture_fit(
			SPRITESHEET_SUN,
			{
				x = f32(sprite_col) * sprite_size.x,
				y = f32(sprite_row) * sprite_size.y,
				w = f32(sprite_size.x),
				h = f32(sprite_size.y),
			},
			{
				x = screen_center.x,
				y = screen_center.y,
				w = sprite_size_scaled.x,
				h = sprite_size_scaled.y,
			},
			sprite_size_scaled / 2,
		)
		// k2.draw_circle(screen_center, scale * SUN_RADIUS, k2.WHITE)
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

