package main

import k2 "karl2d"

TEXTURE_DATA_BACKGROUND :: #load("assets/background.png")

SPRITESHEET_DATA_SUN :: #load("assets/2663172042.png")
SPRITESHEET_SUN_COUNT_X :: 8
SPRITESHEET_SUN_COUNT_Y :: 8
SPRITESHEET_SUN_COUNT_TOTAL :: SPRITESHEET_SUN_COUNT_X * SPRITESHEET_SUN_COUNT_Y

SPRITE_DATA_SHIPS: [PLAYER_COUNT][]u8 = {
	#load("assets/kenney_space-shooter-remastered/PNG/playerShip1_blue.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/playerShip1_green.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/playerShip1_red.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/playerShip1_orange.png"),
}
SPRITE_DATA_BULLETS: [][]u8 = {
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserBlue16.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserGreen10.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserGreen12.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserRed06.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserRed16.png"),
}
SPRITE_DATA_SHIP_EXPLOSIONS: [][][]u8 = {
	{
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_0.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_1.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_2.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_3.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_4.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_5.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_6.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_7.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_8.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_9.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_10.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_11.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_12.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_13.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_14.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_15.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_16.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_17.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_18.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_19.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_20.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_21.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_22.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_23.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_24.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_25.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_26.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_27.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_28.png"),
		#load("assets/fireballs_explosion/fire_ball_side_medium/imgs_explode/img_29.png"),
	},
	{
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_0.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_1.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_2.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_3.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_4.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_5.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_6.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_7.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_8.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_9.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_10.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_11.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_12.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_13.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_14.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_15.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_16.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_17.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_18.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_19.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_20.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_21.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_22.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_23.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_24.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_25.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_26.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_27.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_28.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_29.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_30.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_31.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_32.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_33.png"),
		#load("assets/fireballs_explosion/meteor_side_medium/imgs_explode/img_34.png"),
	},
}
SPRITE_DATA_BULLET_EXPLOSIONS: [][]u8 = {
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserBlue08.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserBlue10.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserBlue09.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserBlue11.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserGreen14.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserGreen16.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserGreen15.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserGreen01.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserRed08.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserRed10.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserRed09.png"),
	#load("assets/kenney_space-shooter-remastered/PNG/Lasers/laserRed11.png"),
}
SOUND_DATA_GUN: [][]u8 = {
	#load("assets/laserLarge_000.wav"),
	#load("assets/laserLarge_001.wav"),
	#load("assets/laserLarge_002.wav"),
	#load("assets/laserLarge_003.wav"),
	#load("assets/laserLarge_004.wav"),
}
SOUND_DATA_EXPLOSION_SHIP: [][]u8 = {
	#load("assets/explosionCrunch_000.wav"),
	#load("assets/explosionCrunch_001.wav"),
	#load("assets/explosionCrunch_002.wav"),
	#load("assets/explosionCrunch_003.wav"),
	#load("assets/explosionCrunch_004.wav"),
}

Sprite_Frame :: struct {
	texture:  k2.Texture,
	src_rect: [4]int,
	scale:    f32,
}

TEXTURE_BACKGROUND: k2.Texture
TEXTURE_SPRITESHEET_SUN: k2.Texture
TEXTURES_BULLET_EXPLOSIONS: [12]k2.Texture
SOUNDS_GUN: [5]k2.Sound
SOUNDS_EXPLOSION_SHIPS: [5]k2.Sound

// Background uses special integer scaling
SPRITESHEET_SUN: [SPRITESHEET_SUN_COUNT_TOTAL]Sprite_Frame
SPRITES_SHIPS: [PLAYER_COUNT]Sprite_Frame
SPRITES_BULLETS: [6]Sprite_Frame
SPRITES_BULLET_EXPLOSIONS: [12]Sprite_Frame
SPRITESHEET_SHIP_EXPLOSION: [dynamic][dynamic]Sprite_Frame
SPRITESHEET_BULLET_EXPLOSION: [PLAYER_COUNT][]Sprite_Frame

sprite_intended_diameter :: proc(sprite: ^Sprite_Frame, diameter: f32) {
	texture_diameter := max(sprite.src_rect.z, sprite.src_rect.w)
	sprite.scale = diameter / f32(texture_diameter)
}

init_assets :: proc() {
	TEXTURE_BACKGROUND = k2.load_texture_from_bytes(TEXTURE_DATA_BACKGROUND)
	TEXTURE_SPRITESHEET_SUN = k2.load_texture_from_bytes(SPRITESHEET_DATA_SUN)
	for i in 0 ..< PLAYER_COUNT {
		sprite := &SPRITES_SHIPS[i]
		sprite^ = {}
		sprite.texture = k2.load_texture_from_bytes(SPRITE_DATA_SHIPS[i])
		sprite.src_rect.z = sprite.texture.width
		sprite.src_rect.w = sprite.texture.height
		sprite_intended_diameter(sprite, 99.0 / 4.0)
	}
	for i in 0 ..< 6 {
		sprite := &SPRITES_BULLETS[i]
		sprite^ = {}
		sprite.texture = k2.load_texture_from_bytes(SPRITE_DATA_BULLETS[i])
		sprite.src_rect.z = sprite.texture.width
		sprite.src_rect.w = sprite.texture.height
		sprite_intended_diameter(sprite, 20.0)
	}
	SPRITESHEET_SHIP_EXPLOSION = make([dynamic][dynamic]Sprite_Frame)
	for buffer_array in SPRITE_DATA_SHIP_EXPLOSIONS {
		sheet := make([dynamic]Sprite_Frame)
		for buffer in buffer_array {
			texture := k2.load_texture_from_bytes(buffer)
			sprite: Sprite_Frame
			sprite.texture = texture
			sprite.src_rect.z = texture.width
			sprite.src_rect.w = texture.height
			sprite.scale = 1
			append(&sheet, sprite)
		}
		append(&SPRITESHEET_SHIP_EXPLOSION, sheet)
	}
	for i in 0 ..< 12 {
		TEXTURES_BULLET_EXPLOSIONS[i] = k2.load_texture_from_bytes(
			SPRITE_DATA_BULLET_EXPLOSIONS[i],
		)
		sprite := &SPRITES_BULLET_EXPLOSIONS[i]
		sprite^ = {}
		sprite.texture = TEXTURES_BULLET_EXPLOSIONS[i]
		sprite.src_rect.z = sprite.texture.width
		sprite.src_rect.w = sprite.texture.height
	}
	for i in 0 ..< 3 {
		sprites := SPRITES_BULLET_EXPLOSIONS[4 * i:][:4]
		sprite_intended_diameter(&sprites[0], 48.0 / 4.0)
		for j in 1 ..< 4 {
			sprites[j].scale = sprites[0].scale
		}
		SPRITESHEET_BULLET_EXPLOSION[i] = sprites
	}
	SPRITESHEET_BULLET_EXPLOSION[3] = SPRITESHEET_BULLET_EXPLOSION[2]

	for i in 0 ..< 5 {
		SOUNDS_GUN[i] = k2.load_sound_from_bytes(SOUND_DATA_GUN[i])
		SOUNDS_EXPLOSION_SHIPS[i] = k2.load_sound_from_bytes(SOUND_DATA_EXPLOSION_SHIP[i])
	}

	for i in 0 ..< SPRITESHEET_SUN_COUNT_TOTAL {
		row := i / SPRITESHEET_SUN_COUNT_X
		col := i % SPRITESHEET_SUN_COUNT_X
		frame_width := TEXTURE_SPRITESHEET_SUN.width / SPRITESHEET_SUN_COUNT_X
		frame_height := TEXTURE_SPRITESHEET_SUN.height / SPRITESHEET_SUN_COUNT_Y
		sprite := &SPRITESHEET_SUN[i]
		sprite^ = {}
		sprite.texture = TEXTURE_SPRITESHEET_SUN
		sprite.src_rect.x = col * frame_width
		sprite.src_rect.y = row * frame_height
		sprite.src_rect.z = frame_width
		sprite.src_rect.w = frame_height
		sprite_intended_diameter(sprite, 72.0 / 4)
	}
}

