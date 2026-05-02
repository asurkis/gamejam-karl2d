package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
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
	alive:             bool,
	kind:              Entity_Kind,
	player_id:         int,
	position:          [2]f32,
	velocity:          [2]f32,
	engine_control:    [2]f32,
	ship_gun_cooldown: f32,
	time_to_live:      f32,
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

PREDICTION_DT :: 1.0 / 64.0
TRAJECTORY_PREDICTION_STEPS :: 8
TRAJECTORY_PREDICTION_STRIDE :: 12

SHIP_COLORS: [PLAYER_COUNT]k2.Color = {k2.BLUE, k2.GREEN, k2.RED, k2.YELLOW}

init :: proc() {
	k2.init(1280, 720, "Korableke 2", {window_mode = .Windowed_Resizable})
	init_game_state()
}

init_game_state :: proc() {
	entity_reinit_all()
	for i in 0 ..< PLAYER_COUNT {
		ship, _ := entity_new()
		ship.kind = .Ship
		ship.player_id = i
		sin, cos := math.sincos(math.TAU * f32(i) / f32(PLAYER_COUNT))
		ship.position = STARTING_RADIUS * {cos, sin}
		ship.velocity = STARTING_VELOCITY * {-sin, cos}
		ship.engine_control = 0
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

shoot_bullet :: proc(ship: ^Entity) {
	if ship.ship_gun_cooldown > 0 do return
	ship.ship_gun_cooldown = 0.25
	forward := linalg.normalize0(ship.velocity)
	bullet, _ := entity_new()
	bullet.kind = .Bullet
	bullet.player_id = ship.player_id
	bullet.position = ship.position + BULLET_MUZZLE_DISTANCE * forward
	bullet.velocity = ship.velocity + BULLET_MUZZLE_SPEED * forward
	bullet.engine_control = 0
	bullet.time_to_live = 4
}

step :: proc() -> bool {
	if !k2.update() do return false
	k2.clear(k2.DARK_BLUE)
	if k2.key_went_down(.R) do init_game_state()
	dt := k2.get_frame_time()
	text := fmt.aprintf("FPS: %f", 1 / dt, allocator = context.temp_allocator)
	k2.draw_text(text, {30, 30}, 30, k2.WHITE)
	screen_width := k2.get_screen_width()
	screen_height := k2.get_screen_height()
	screen_size := [2]f32{f32(screen_width), f32(screen_height)}
	screen_center := screen_size / 2
	screen_min_size := min(screen_size.x, screen_size.y)
	scale := screen_min_size / PLAYGROUND_SIZE

	// Controls + physics
	for &entity, entity_idx in entities {
		if !entity.alive do continue
		switch entity.kind {
		case .Ship:
			entity.ship_gun_cooldown = max(0, entity.ship_gun_cooldown - dt)
			if entity.player_id == 0 {
				entity.engine_control = 0
				if k2.key_is_held(.Up) do entity.engine_control.y += FORWARD_ENGINE_STRENGTH
				if k2.key_is_held(.Down) do entity.engine_control.y -= BACK_ENGINE_STRENGTH
				if k2.key_is_held(.Right) do entity.engine_control.x += SIDE_ENGINE_STRENGTH
				if k2.key_is_held(.Left) do entity.engine_control.x -= SIDE_ENGINE_STRENGTH
				if k2.key_is_held(.Space) do shoot_bullet(&entity)
			}
		case .Bullet, .Explosion:
			entity.time_to_live -= dt
			if entity.time_to_live <= 0 {
				entity_free(entity_idx)
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
	for ship, ship_idx in entities {
		if !ship.alive do continue
		if ship.kind != .Ship do continue
		for bullet, bullet_idx in entities {
			if ship_idx == bullet_idx do continue
			if !bullet.alive do continue
			if bullet.kind != .Bullet do continue
			distance := linalg.length(ship.position - bullet.position)
			if distance > SHIP_RADIUS do continue
			explosion, _ := entity_new()
			explosion.kind = .Explosion
			explosion.player_id = -1
			explosion.position = ship.position
			explosion.velocity = ship.velocity
			explosion.time_to_live = 2
			entity_free(bullet_idx)
		}
	}

	// Render
	for &entity, entity_idx in entities {
		if !entity.alive do continue
		switch entity.kind {
		case .Ship:
			k2.draw_circle(
				screen_center + scale * entity.position,
				scale * SHIP_RADIUS,
				SHIP_COLORS[entity.player_id],
			)
		case .Bullet:
			k2.draw_circle(
				screen_center + scale * entity.position,
				5,
				SHIP_COLORS[entity.player_id],
			)
		case .Explosion:
			color := k2.ORANGE
			color.w = u8(255 * clamp(1 - entity.time_to_live / 2, 0, 1))
			k2.draw_circle(
				screen_center + scale * entity.position,
				90 - 30 * entity.time_to_live,
				color,
			)
		}

		if entity.kind == .Ship && entity.player_id == 0 {
			prediction_copy := entity
			prediction_copy.engine_control = 0
			for j in 1 ..= TRAJECTORY_PREDICTION_STEPS {
				for _ in 0 ..< TRAJECTORY_PREDICTION_STRIDE {
					do_physics_step(&prediction_copy, PREDICTION_DT)
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
	k2.present()
	free_all(context.temp_allocator)
	return true
}

shutdown :: proc() {
	k2.shutdown()
}

