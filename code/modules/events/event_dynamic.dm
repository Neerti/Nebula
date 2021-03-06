var/list/event_last_fired = list()

//Always triggers an event when called, dynamically chooses events based on job population
/proc/spawn_dynamic_event()
	if(!config.allow_random_events)
		return

	var/minutes_passed = world.time/600

	var/list/active_with_role = number_active_with_role()

	// Maps event names to event chances
	// For each chance, 100 represents "normal likelihood", anything below 100 is "reduced likelihood", anything above 100 is "increased likelihood"
	// Events have to be manually added to this proc to happen
	var/list/possibleEvents = list()

	//see:
	// Code/WorkInProgress/Cael_Aislinn/Economy/Economy_Events.dm
	// Code/WorkInProgress/Cael_Aislinn/Economy/Economy_Events_Mundane.dm

	possibleEvents[/datum/event/location_event/mundane_news] = 300
	possibleEvents[/datum/event/trivial_news] = 400
	possibleEvents[/datum/event/location_event] = 300

	possibleEvents[/datum/event/money_lotto] = max(min(5, GLOB.player_list.len), 50)
	if(account_hack_attempted)
		possibleEvents[/datum/event/money_hacker] = max(min(25, GLOB.player_list.len) * 4, 200)


	possibleEvents[/datum/event/carp_migration] = 20 + 10 * active_with_role["Engineer"]
	possibleEvents[/datum/event/brand_intelligence] = 10 + 10 * active_with_role["Janitor"]

	possibleEvents[/datum/event/rogue_drone] = 5 + 25 * active_with_role["Engineer"] + 25 * active_with_role["Security"]
	possibleEvents[/datum/event/infestation] = 100 + 100 * active_with_role["Janitor"]

	possibleEvents[/datum/event/communications_blackout] = 50 + 25 * active_with_role["AI"] + active_with_role["Scientist"] * 25
	possibleEvents[/datum/event/ionstorm] = active_with_role["AI"] * 25 + active_with_role["Robot"] * 25 + active_with_role["Engineer"] * 10 + active_with_role["Scientist"] * 5
	possibleEvents[/datum/event/grid_check] = 25 + 10 * active_with_role["Engineer"]
	possibleEvents[/datum/event/electrical_storm] = 15 * active_with_role["Janitor"] + 5 * active_with_role["Engineer"]
	possibleEvents[/datum/event/wallrot] = 30 * active_with_role["Engineer"] + 50 * active_with_role["Gardener"]

	if(!spacevines_spawned)
		possibleEvents[/datum/event/spacevine] = 10 + 5 * active_with_role["Engineer"]
	if(minutes_passed >= 30) // Give engineers time to set up engine
		possibleEvents[/datum/event/meteor_wave] = 10 * active_with_role["Engineer"]
		possibleEvents[/datum/event/blob] = 10 * active_with_role["Engineer"]

	if(active_with_role["Medical"] > 0)
		possibleEvents[/datum/event/radiation_storm] = active_with_role["Medical"] * 10
		possibleEvents[/datum/event/spontaneous_appendicitis] = active_with_role["Medical"] * 10

	possibleEvents[/datum/event/prison_break] = active_with_role["Security"] * 50
	if(active_with_role["Security"] > 0)
		if(!sent_spiders_to_station)
			possibleEvents[/datum/event/spider_infestation] = max(active_with_role["Security"], 5) + 5
		possibleEvents[/datum/event/random_antag] = max(active_with_role["Security"], 5) + 2.5

	for(var/event_type in event_last_fired) if(possibleEvents[event_type])
		var/time_passed = world.time - event_last_fired[event_type]
		var/full_recharge_after = 60 * 60 * 10 * 3 // 3 hours
		var/weight_modifier = max(0, (full_recharge_after - time_passed) / 300)

		possibleEvents[event_type] = max(possibleEvents[event_type] - weight_modifier, 0)

	var/picked_event = pickweight(possibleEvents)
	event_last_fired[picked_event] = world.time

	// Debug code below here, very useful for testing so don't delete please.
	var/debug_message = "Firing random event. "
	for(var/V in active_with_role)
		debug_message += "#[V]:[active_with_role[V]] "
	debug_message += "||| "
	for(var/V in possibleEvents)
		debug_message += "[V]:[possibleEvents[V]]"
	debug_message += "|||Picked:[picked_event]"
	log_debug(debug_message)

	if(!picked_event)
		return

	//The event will add itself to the MC's event list
	//and start working via the constructor.
	new picked_event
	return 1

// Returns how many characters are currently active(not logged out, not AFK for more than 10 minutes)
// with a specific role.
// Note that this isn't sorted by department, because e.g. having a roboticist shouldn't make meteors spawn.
/proc/number_active_with_role()

	. = list()
	for(var/mob/M in GLOB.player_list)

		if(!M.mind || !M.client || M.client.is_afk(10 MINUTES))
			continue

		.["Any"]++

		if(istype(M, /mob/living/silicon/robot))
			var/mob/living/silicon/robot/R = M
			if(R.module.associated_department)
				var/decl/department/dept = decls_repository.get_decl(R.module.associated_department)
				.[dept.name] = .[dept.name] + 1
		else
			for(var/dtype in M.mind.assigned_job.department_types)
				var/decl/department/dept = decls_repository.get_decl(dtype)
				.[dept.name] = .[dept.name] + 1
				for(var/job_category in M.mind.assigned_job.event_categories)
					.[job_category] = .[job_category] + 1
