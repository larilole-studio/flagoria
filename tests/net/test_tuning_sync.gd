extends "res://tests/helpers/test_helpers.gd"

const PROBE := "res://tests/tuning_sync_probe.gd"


func _test_tuning_sync() -> int:
	print("-- test_tuning_sync")
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL tuning_sync: no free port")
		return 1
	var dir := make_probe_dir("tuning_sync_%d_%d" % [OS.get_process_id(), port])
	var args := ["--port=%d" % port]
	var probes: Array[Dictionary] = [
		spawn_probe(PROBE, dir.path_join("p0.json"), args + ["--host"]),
		spawn_probe(PROBE, dir.path_join("p1.json"), args),
	]
	await wait_until(func() -> bool: return read_probe_at(1, probes).get("done", false), 30000)
	var client := read_probe_at(1, probes)
	var host := (
		await wait_result(probes[0], 8000)
		if client.get("passed", false)
		else read_probe_at(0, probes)
	)
	await stop_probes(probes, 5000)
	_remove_dir(dir)
	for peer in [host, client]:
		if not peer.get("passed", false) or not peer.get("errors", []).is_empty():
			printerr("FAIL tuning_sync: host %s, client %s" % [host, client])
			return 1
	print("PASS test_tuning_sync")
	return 0
