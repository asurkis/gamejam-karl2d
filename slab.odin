package main

entities: [dynamic]Entity
entities_free_list: [dynamic]int

entity_reinit_all :: proc() {
	delete(entities)
	delete(entities_free_list)
	entities = make([dynamic]Entity)
	entities_free_list = make([dynamic]int)
}

entity_new :: proc() -> (ptr: ^Entity, idx: int) {
	if len(entities_free_list) == 0 {
		idx = len(entities)
		append(&entities, Entity{})
	} else {
		idx = pop(&entities_free_list)
	}
	ptr = &entities[idx]
	ptr^ = {}
	ptr.alive = true
	return
}

entity_free :: proc(idx: int) {
	entities[idx] = {}
	append(&entities_free_list, idx)
}

