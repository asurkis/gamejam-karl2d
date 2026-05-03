package main

entities: [dynamic]Entity
entities_free_list: [dynamic]int
entities_spawn_queue: [dynamic]Entity

entity_reinit_all :: proc() {
	delete(entities)
	delete(entities_free_list)
	delete(entities_spawn_queue)
	entities = make([dynamic]Entity)
	entities_free_list = make([dynamic]int)
	entities_spawn_queue = make([dynamic]Entity)
}

entity_new :: proc() -> ^Entity {
	idx := len(entities_spawn_queue)
	append(&entities_spawn_queue, Entity{})
	return &entities_spawn_queue[idx]
}

entity_commit :: proc() {
	for it in entities_spawn_queue {
		idx: int
		if len(entities_free_list) == 0 {
			idx = len(entities)
			append(&entities, Entity{})
		} else {
			idx = pop(&entities_free_list)
		}
		ptr := &entities[idx]
		ptr^ = it
		ptr.alive = true
	}
	clear(&entities_spawn_queue)
}

entity_free :: proc(idx: int) {
	entities[idx] = {}
	append(&entities_free_list, idx)
}

