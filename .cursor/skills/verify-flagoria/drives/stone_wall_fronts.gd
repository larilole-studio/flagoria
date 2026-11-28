extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11


func run() -> void:
	if not await start_game():
		return
	step("starting-castle")
	for frame in 30:
		await physics_frame
	await snapshot("wall-runs-and-corners")
	done(true)
