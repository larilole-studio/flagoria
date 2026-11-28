extends "res://tests/helpers/test_helpers.gd"


func _test_soldier_formation_losses_and_save() -> int:
	print("-- test_soldier_formation_losses_and_save")
	var scene := mount_main_scene()
	var troops: SoldierRequests = scene.get_node("World/Soldiers")
	troops.set_physics_process(false)
	var formations := SoldierFormations.new()
	for i in 20:
		troops.spawn_saved(
			{
				"name": "formation_test_%d" % i,
				"owner": 1,
				"order": "hold",
				"barracks_anchor": Vector2i(i % 2, 0),
				"pos": Vector2(208 + i, 208)
			}
		)
	for i in 5:
		formations.refresh(troops)
	var active := troops.soldiers()
	var ok: bool = active.size() == 1 and active[0].member_count() == 20 and active[0].hp == 80
	if not ok:
		printerr("FAIL soldier_formation_losses_and_save: 20 soldiers did not form a company")
		scene.queue_free()
		await process_frame
		return 1
	var company: Soldier = active[0]
	var saved := SoldierSaves.capture(scene)
	company.queue_free()
	await process_frame
	ok = SoldierSaves.restore(saved, troops) == 1 and troops.soldiers().size() == 1
	company = troops.soldiers()[0]
	ok = ok and company.member_count() == 20 and company.member_anchors.count(Vector2i.ZERO) == 10
	ok = ok and company.strike_damage() == 4 and company.take_hit(2, 60)
	formations.refresh(troops)
	var pieces := troops.soldiers()
	ok = ok and pieces.size() == 1 and pieces[0].member_count() == 5 and pieces[0].hp == 20
	if ok:
		var squad: Soldier = pieces[0]
		ok = squad.take_hit(2, 6)
		formations.refresh(troops)
		pieces = troops.soldiers()
		ok = ok and pieces.size() == 4
		var hp := 0
		for piece: Soldier in pieces:
			ok = ok and piece.member_count() == 1
			hp += piece.hp
		ok = ok and hp == 14
	scene.queue_free()
	await process_frame
	if ok:
		print("PASS test_soldier_formation_losses_and_save")
	else:
		printerr("FAIL soldier_formation_losses_and_save: saved provenance or split HP mismatch")
	return 0 if ok else 1
