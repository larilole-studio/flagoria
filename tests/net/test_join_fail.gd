extends "res://tests/helpers/test_helpers.gd"
## A connected client recovers after its host exits (#348).


func _test_join_fail_host_quits() -> int:
	## A client whose host process exits lands back on the main menu. Runs
	## tests/join_fail_probe.gd in its own process (leave reloads the current
	## scene). The probe dials after the server log says it is listening, so
	## a slow boot does not burn the unanswered-join timeout. Time cost:
	## ~6–8 s in verify (~12 s alone with --only=).
	print("-- test_join_fail_host_quits")
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL join_fail_host_quits found no free UDP port")
		return 1
	var output := []
	var code := OS.execute(
		OS.get_executable_path(),
		[
			"--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after", "20000",
			"--script", "res://tests/join_fail_probe.gd", "--", "--port=%d" % port,
		],
		output,
		true
	)
	var log_text: String = "".join(output)
	if code != 0 or not log_text.contains("JOIN_FAIL_PROBE_OK"):
		for line in log_text.split("\n"):
			if line.contains("join_fail_probe") or line.contains("FAIL"):
				printerr(line)
		printerr("FAIL join_fail_host_quits probe exit=%s" % code)
		return 1
	print("PASS test_join_fail_host_quits")
	return 0
