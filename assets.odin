package main

TEXTURE_DATA_BACKGROUND :: #load("assets/background.png")

SPRITESHEET_DATA_SUN :: #load("assets/2663172042.png")
SPRITESHEET_SUN_COUNT_X :: 8
SPRITESHEET_SUN_COUNT_Y :: 8
SPRITESHEET_SUN_COUNT_TOTAL :: SPRITESHEET_SUN_COUNT_X * SPRITESHEET_SUN_COUNT_Y

SPRITE_DATA_SHIPS: [PLAYER_COUNT][]u8 = {
	#load("kenney_space-shooter-remastered/PNG/playerShip1_blue.png"),
	#load("kenney_space-shooter-remastered/PNG/playerShip1_green.png"),
	#load("kenney_space-shooter-remastered/PNG/playerShip1_red.png"),
	#load("kenney_space-shooter-remastered/PNG/playerShip1_orange.png"),
}
SPRITE_DATA_BULLETS: [][]u8 = {
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue16.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserGreen10.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserGreen12.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserRed06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserRed16.png"),
}
SOUND_DATA_GUN: [][]u8 = {
	#load("assets/laserLarge_000.wav"),
	#load("assets/laserLarge_001.wav"),
	#load("assets/laserLarge_002.wav"),
	#load("assets/laserLarge_003.wav"),
	#load("assets/laserLarge_004.wav"),
}
SPRITE_DATA_BULLET_EXPLOSIONS: [][]u8 = {
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
	#load("kenney_space-shooter-remastered/PNG/Lasers/laserBlue06.png"),
}

