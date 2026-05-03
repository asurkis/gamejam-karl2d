package main

// import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import k2 "karl2d"

CPU_TRAJECTORY_PREDICTION_DT :: 1.0 / 4.0
CPU_TRAJECTORY_PREDICTION_STEPS :: 32
CPU_SUN_MARGIN :: SHIP_RADIUS + SUN_RADIUS
CPU_SHIP_MARGIN :: 2.5 * SHIP_RADIUS
CPU_BULLET_MARGIN :: 1.5 * SHIP_RADIUS

strategy_player :: proc(ship: ^Entity, ship_id: int) {
	ship.engine_control = 0
	if k2.key_is_held(.Up) || k2.key_is_held(.W) do ship.engine_control.y += 1
	if k2.key_is_held(.Down) || k2.key_is_held(.S) do ship.engine_control.y -= 1
	if k2.key_is_held(.Right) || k2.key_is_held(.D) do ship.engine_control.x += 1
	if k2.key_is_held(.Left) || k2.key_is_held(.A) do ship.engine_control.x -= 1
	if k2.key_is_held(.Space) do ship_shoot_bullet(ship)
}

strategy_cpu1 :: proc(ship: ^Entity, ship_id: int) {
	ship_shoot_bullet(ship)
}

strategy_cpu2 :: proc(ship: ^Entity, ship_id: int) {
	engine_control_variants: [5][2]f32
	engine_control_variants[1].y = 1
	engine_control_variants[2].y = -1
	engine_control_variants[3].x = 1
	engine_control_variants[4].y = -1
	best_engine_control := engine_control_variants[0]
	best_min_distance_of_shot := math.INF_F32
	frame_distance_of_shot := math.INF_F32
	best_target_id := -1
	for variant_engine_control in engine_control_variants {
		variant_min_distance_of_shot := math.INF_F32
		variant_best_target_id := -1
		avoid_sun := true
		{
			my_prediction := ship^
			for _ in 0 ..< CPU_TRAJECTORY_PREDICTION_STEPS {
				do_physics_step(&my_prediction, CPU_TRAJECTORY_PREDICTION_DT)
				distance_to_sun := linalg.length(my_prediction.position)
				avoid_sun &= distance_to_sun > CPU_SUN_MARGIN
			}
		}
		if !avoid_sun do continue

		avoid_collision := true
		for target, target_id in entities {
			if !avoid_collision do break
			if !target.alive do continue
			if ship_id == target_id do continue
			if target.kind != .Ship do continue
			if target.ship_time_to_respawn > 0 do continue
			my_prediction := ship^
			my_prediction.engine_control = variant_engine_control
			target_prediction := target
			shot_down_before := 0x7FFF_FFFF
			for frames_before_shot in 0 ..< CPU_TRAJECTORY_PREDICTION_STEPS {
				if frames_before_shot > shot_down_before do break
				distance_between_ships := linalg.length(
					my_prediction.position - target_prediction.position,
				)
				if distance_between_ships < CPU_SHIP_MARGIN {
					avoid_collision = false
					break
				}
				bullet := bullet_data_if_shot(my_prediction)
				prediction := target_prediction
				for bullet_frames in 0 ..< CPU_TRAJECTORY_PREDICTION_STEPS {
					distance_bullet_target := linalg.length(bullet.position - prediction.position)
					if distance_bullet_target < CPU_BULLET_MARGIN {
						shot_down_before = min(
							shot_down_before,
							bullet_frames + frames_before_shot,
						)
					}
					if variant_min_distance_of_shot > distance_bullet_target {
						variant_min_distance_of_shot = distance_bullet_target
						variant_best_target_id = target_id
					}
					if frames_before_shot == 0 {
						if frame_distance_of_shot > distance_bullet_target {
							frame_distance_of_shot = distance_bullet_target
						}
					}
					do_physics_step(&bullet, CPU_TRAJECTORY_PREDICTION_DT)
					do_physics_step(&prediction, CPU_TRAJECTORY_PREDICTION_DT)
				}
				do_physics_step(&my_prediction, CPU_TRAJECTORY_PREDICTION_DT)
				do_physics_step(&target_prediction, CPU_TRAJECTORY_PREDICTION_DT)
			}
		}
		if !avoid_collision do continue

		if best_min_distance_of_shot > variant_min_distance_of_shot {
			best_min_distance_of_shot = variant_min_distance_of_shot
			best_engine_control = variant_engine_control
			best_target_id = variant_best_target_id
		}
	}
	ship.engine_control = best_engine_control
	if frame_distance_of_shot <= CPU_BULLET_MARGIN do ship_shoot_bullet(ship)
}

strategy_cpu3 :: proc(ship: ^Entity, ship_id: int, dt: f32) {
	// To ensure smooth work of CPU 2, we only switch controls for CPU 3 once every few frames
	ship.cpu3_time_since_switch += dt
	if ship.cpu3_time_since_switch >= 0.25 {
		ship.engine_control.x = rand.float32_normal(0, 1)
		ship.engine_control.y = rand.float32_normal(0, 1)
		ship.cpu3_time_since_switch = 0
	}
	// If we're too far from the sun, return to the playing area regardless
	distance_from_sun := linalg.length(ship.position)
	if distance_from_sun > PLAYGROUND_SIZE / 4 {
		forward := linalg.normalize0(ship.velocity)
		ship.engine_control.x = 0
		ship.engine_control.y = -math.sign(linalg.dot(forward, ship.position))
	}
	ship_shoot_bullet(ship)
}

