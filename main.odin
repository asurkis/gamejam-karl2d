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
	alive:                bool,
	kind:                 Entity_Kind,
	player_id:            int,
	position:             [2]f32,
	velocity:             [2]f32,
	engine_control:       [2]f32,
	ship_gun_cooldown:    f32,
	ship_time_to_respawn: f32,
	time_to_live:         f32,
}

PLAYER_COUNT :: 4
PLAYGROUND_SIZE :: 720
SUN_RADIUS :: 36
SHIP_RADIUS :: 10
STARTING_RADIUS :: 90
STARTING_VELOCITY :: 60
GRAVITY_STRENGTH :: STARTING_VELOCITY * STARTING_VELOCITY * STARTING_RADIUS
FORWARD_ENGINE_STRENGTH :: 20
BACK_ENGINE_STRENGTH :: 10
SIDE_ENGINE_STRENGTH :: 5
BULLET_MUZZLE_DISTANCE :: SHIP_RADIUS + 5
BULLET_MUZZLE_SPEED :: 90

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

init_game_state :: proc() {
	entity_reinit_all()
	score_table = {}
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
	if engine_power.y < 0 {
		engine_power.y = max(engine_power.y, -gravity_tang - vel_mag / dt)
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
	bullet.time_to_live = 4
	return
}

ship_shoot_bullet :: proc(ship: ^Entity) {
	if ship.ship_gun_cooldown > 0 do return
	if ship.ship_time_to_respawn > 0 do return
	ship.ship_gun_cooldown = 0.25
	bullet, _ := entity_new()
	bullet^ = bullet_data_if_shot(ship^)
}

ship_respawn :: proc(ship: ^Entity, phase: f32) {
	sin, cos := math.sincos(phase)
	ship.position = STARTING_RADIUS * {cos, sin}
	ship.velocity = STARTING_VELOCITY * {-sin, cos}
	ship.engine_control = 0
}

ship_die :: proc(ship: ^Entity) {
	explosion, _ := entity_new()
	explosion.kind = .Explosion
	explosion.player_id = -1
	explosion.position = ship.position
	explosion.velocity = ship.velocity
	explosion.time_to_live = 2

	phase := rand.float32_range(-math.PI, math.PI)
	ship_respawn(ship, phase)
	ship.ship_time_to_respawn = 3
}

step :: proc() -> bool {
	if !k2.update() do return false
	k2.clear(k2.DARK_BLUE)
	if k2.key_went_down(.R) do init_game_state()
	dt := k2.get_frame_time()
	screen_width := k2.get_screen_width()
	screen_height := k2.get_screen_height()
	screen_size := [2]f32{f32(screen_width), f32(screen_height)}
	screen_center := screen_size / 2
	screen_min_size := min(screen_size.x, screen_size.y)
	scale := screen_min_size / PLAYGROUND_SIZE

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
				strategy_cpu1(&entity, entity_id)
			case 2:
				strategy_cpu2(&entity, entity_id)
			case 3:
				strategy_cpu3(&entity, entity_id)
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
		for bullet, bullet_id in entities {
			if ship_id == bullet_id do continue
			if !bullet.alive do continue
			if bullet.kind != .Bullet do continue
			distance := linalg.length(ship.position - bullet.position)
			if distance > SHIP_RADIUS do continue

			if ship.player_id == bullet.player_id {
				score_table[bullet.player_id] -= 1
			} else {
				score_table[bullet.player_id] += 1
			}

			ship_die(&ship)
			entity_free(bullet_id)
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
			color.w = u8(255 * clamp(entity.time_to_live / 2, 0, 1))
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

	k2.draw_text(fmt.tprintf("FPS: %f", 1 / dt), {15, 15}, 30, k2.WHITE)
	for i in 0 ..< PLAYER_COUNT {
		k2.draw_text(
			fmt.tprintf("%s:\t%d", PLAYER_NAMES[i], score_table[i]),
			{15, 60 + 30 * f32(i)},
			30,
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

