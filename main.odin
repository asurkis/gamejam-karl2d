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

Ship :: struct {
	pos:   [2]f32,
	vel:   [2]f32,
	alive: bool,
}

MAX_SHIPS :: 4
SUN_RADIUS :: 1
STARTING_RADIUS :: 5
STARTING_VELOCITY :: 3
GRAVITY_STRENGTH :: STARTING_VELOCITY * STARTING_VELOCITY * STARTING_RADIUS
FORWARD_ENGINE_STRENGTH :: 2
BACK_ENGINE_STRENGTH :: 1
SIDE_ENGINE_STRENGTH :: 0.5

PREDICTION_DT :: 1.0 / 64.0
TRAJECTORY_PREDICTION_STEPS :: 8
TRAJECTORY_PREDICTION_STRIDE :: 12

SHIP_COLORS: [MAX_SHIPS]k2.Color = {k2.LIGHT_GREEN, k2.LIGHT_RED, k2.LIGHT_BLUE, k2.LIGHT_PURPLE}

ships: [MAX_SHIPS]Ship

init :: proc() {
	k2.init(1280, 720, "Korableke 2", {window_mode = .Windowed_Resizable})
	init_game_state()
}

init_game_state :: proc() {
	init_ships := MAX_SHIPS
	for i in 0 ..< MAX_SHIPS {
		ship := &ships[i]
		sin, cos := math.sincos(math.TAU * f32(i) / f32(init_ships))
		ship.pos = STARTING_RADIUS * {cos, sin}
		ship.vel = STARTING_VELOCITY * {-sin, cos}
		ship.alive = i < init_ships
	}
}

calc_gravity :: proc(pos: [2]f32) -> [2]f32 {
	distance_from_sun := linalg.length(pos)
	return -GRAVITY_STRENGTH * pos / distance_from_sun / distance_from_sun / distance_from_sun
}

predict_trajectory :: proc(ship: Ship) -> (out: [TRAJECTORY_PREDICTION_STEPS][2]f32) {
	pos := ship.pos
	vel := ship.vel
	for i in 0 ..< TRAJECTORY_PREDICTION_STEPS {
		for _ in 0 ..< TRAJECTORY_PREDICTION_STRIDE {
			acc := calc_gravity(pos)
			vel += PREDICTION_DT * acc
			pos += PREDICTION_DT * vel
		}
		out[i] = pos
	}
	return
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
	scale := screen_min_size / 20
	for &ship, i in ships {
		acc := calc_gravity(ship.pos)
		if i == 0 {
			vel_mag := linalg.length(ship.vel)
			forward := ship.vel / vel_mag
			right: [2]f32 = {-forward.y, forward.x}
			if k2.key_is_held(.Up) do acc += FORWARD_ENGINE_STRENGTH * forward
			if k2.key_is_held(.Down) {
				decel := min(vel_mag, BACK_ENGINE_STRENGTH)
				acc -= decel * forward
			}
			if k2.key_is_held(.Right) do acc += SIDE_ENGINE_STRENGTH * right
			if k2.key_is_held(.Left) do acc -= SIDE_ENGINE_STRENGTH * right
			k2.draw_line(
				screen_center + scale * ship.pos,
				screen_center + scale * ship.pos + 100 * forward,
				3,
				k2.RED,
			)
			k2.draw_line(
				screen_center + scale * ship.pos,
				screen_center + scale * ship.pos + 100 * right,
				3,
				k2.BLUE,
			)
		}
		ship.vel += dt * acc
		ship.pos += dt * ship.vel
		k2.draw_circle(screen_center + scale * ship.pos, 20, SHIP_COLORS[i])
		prediction := predict_trajectory(ship)
		for pt, j in prediction {
			radius := 5 / f32(j + 1)
			k2.draw_circle(screen_center + scale * pt, radius, SHIP_COLORS[i])
		}
	}
	k2.draw_circle(screen_center, scale * SUN_RADIUS, k2.YELLOW)
	k2.present()
	free_all(context.temp_allocator)
	return true
}

shutdown :: proc() {
	k2.shutdown()
}

