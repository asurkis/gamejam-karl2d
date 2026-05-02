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
	ship_time_to_respawn:   f32,
	time_to_live:           f32,
	cpu3_time_since_switch: f32,
}

PLAYER_COUNT :: 4
PLAYGROUND_SIZE :: 720.0
SUN_RADIUS :: 36.0
SHIP_RADIUS :: 10.0
STARTING_RADIUS :: 180.0
STARTING_VELOCITY :: 90.0
GRAVITY_STRENGTH :: STARTING_VELOCITY * STARTING_VELOCITY * STARTING_RADIUS

SHIP_ENGINE_POWER_FORWARD :: 20.0
SHIP_ENGINE_POWER_BACK :: 7.0
SHIP_ENGINE_POWER_SIDE :: 5.0

SHIP_GUN_COOLDOWN :: 0.5
SHIP_TIME_TO_RESPAWN :: 3.0

BULLET_MUZZLE_DISTANCE :: SHIP_RADIUS + 5
BULLET_MUZZLE_SPEED :: 180.0
BULLET_TTL :: 4.0

EXPLOSION_DURATION :: 2.0

SCORE_SUN_COLLISION :: -2
SCORE_SHIP_COLLISION :: -1
SCORE_GUN_KILL :: 1
SCORE_GUN_KILL_SELF :: -1

PLAYER_TRAJECTORY_PREDICTION_DT :: 1.0 / 64.0
PLAYER_TRAJECTORY_PREDICTION_STEPS :: 8
PLAYER_TRAJECTORY_PREDICTION_STRIDE :: 12

SHIP_COLORS: [PLAYER_COUNT]k2.Color = {k2.BLUE, k2.GREEN, k2.RED, k2.YELLOW}

init :: proc() {
	k2.init(1280, 720, "Korableke 2", {window_mode = .Windowed_Resizable})
	init_game_state()
}

PLAYER_NAMES: [PLAYER_COUNT]string = {"Player", "CPU 1", "CPU 2", "CPU 3"}
score_table: [PLAYER_COUNT]int
game_time_remaining: f32
animation_ttl: f32

init_game_state :: proc() {
	entity_reinit_all()
	score_table = {}
	game_time_remaining = 120
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

		if entity.kind == .Ship && entity.player_id == 0 {
			vel_mag := linalg.length(entity.velocity)
			forward := entity.velocity / vel_mag
			right: [2]f32 = {-forward.y, forward.x}
			k2.draw_line(
				screen_center + scale * entity.position,
				screen_center + scale * entity.position + 100 * forward,
				3,
				k2.RED,
			)
			k2.draw_line(
				screen_center + scale * entity.position,
				screen_center + scale * entity.position + 100 * right,
				3,
				k2.BLUE,
			)
		}
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

			if ship.player_id == bullet.player_id {
				score_table[bullet.player_id] += SCORE_GUN_KILL_SELF
			} else {
				score_table[bullet.player_id] += SCORE_GUN_KILL
			}

			ship_die(&ship)
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
			color := SHIP_COLORS[entity.player_id]
			if entity.ship_time_to_respawn > 0 do color.w = 127
			k2.draw_circle(screen_center + scale * entity.position, scale * SHIP_RADIUS, color)
		case .Bullet:
			k2.draw_circle(
				screen_center + scale * entity.position,
				5,
				SHIP_COLORS[entity.player_id],
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
					SHIP_COLORS[entity.player_id],
				)
			}
		}
	}
	k2.draw_circle(screen_center, scale * SUN_RADIUS, k2.WHITE)

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

