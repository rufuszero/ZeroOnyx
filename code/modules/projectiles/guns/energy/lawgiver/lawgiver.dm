// Lawgiver gun is a reference to the Judge Dredd universe created by John Wagner and Carlos Ezquerra.
// This specific version is based on the version from the movie Dredd (2012) https://www.imdb.com/title/tt1343727/.
// Copyright:
// Dredd (Movie, 2012) - Rena Films (PTY) Ltd and Peach Tree Films Ltd.
// Judge Dredd (character), Lawgiver, and other materials from "2000AD" universe - Rebellion Developments Ltd.
/obj/item/gun/energy/lawgiver
	name = "lawgiver"
	desc = "The Lawgiver II-E, an energy-based continuation of the unique Lawgiver series.\n\
	This advanced adaptive sidearm features mission-variable, voice-programmed ammunition, \
	with support for <b>stun, laser, rapid-fire, flash, and armor-piercing modes</b>.\n\
	Equipped with several security features, including a <b>DNA sensor</b> handgrip, it allows access \
	only to the operator it is registered to."
	icon_state = "lawgiver"
	item_state = "lawgiver"
	// inherited flags + KEEP_TOGETHER for grouping display together with the lawgiver
	appearance_flags = DEFAULT_APPEARANCE_FLAGS | TILE_BOUND | KEEP_TOGETHER
	origin_tech = list(TECH_COMBAT = 5, TECH_MATERIAL = 5, TECH_ENGINEERING = 5)
	screen_shake = 0
	cell_type = /obj/item/cell/magazine/lawgiver
	charge_meter = FALSE
	projectile_type = null
	firemodes = list(
		new /datum/firemode/lawgiver/stun,
		new /datum/firemode/lawgiver/laser,
		new /datum/firemode/lawgiver/rapid,
		new /datum/firemode/lawgiver/flash,
		new /datum/firemode/lawgiver/armorpierce)
	var/obj/lawgiver_display/display
	var/registered_owner_dna
	var/unload_sound = 'sound/effects/weapons/energy/lawgiver/unload.ogg'
	var/reload_sound = 'sound/effects/weapons/energy/lawgiver/reload.ogg'
	var/mag_overlay_icon_state = "lawgiver_overlay_mag"
	var/emagged = FALSE
	// see flashlight defines and atom lighting for more information on these values
	var/flashlight_enabled = FALSE
	var/flashlight_max_bright = 0.5
	var/flashlight_inner_range = 1
	var/flashlight_outer_range = 4
	var/flashlight_falloff_curve = 4
	var/flashlight_color = "#ffffff" // following security maglights, pure white lighting
	var/flashlight_toggle_sound = 'sound/effects/weapons/energy/lawgiver/flashlight_click.ogg'
	var/flashlight_overlay_icon_state = "lawgiver_overlay_flashlight"

/obj/item/gun/energy/lawgiver/Initialize()
	. = ..()
	update_verbs()

	GLOB.listening_objects += src

	description_info += "\n\n"
	var/firemode_keywords_info = "The following firemodes can be activated if registered operator speaks one of the keywords:\n\n"
	for(var/datum/firemode/lawgiver/mode in firemodes)
		firemode_keywords_info += "[capitalize(mode.name)] - [jointext(mode.keywords, ", ")]\n"
	description_info = description_info + firemode_keywords_info

	description_info += "\n"
	description_info += "Activating \the [src] in hands will toggle the integrated flashlight module.\n\
						 \n\
						 Alt-clicking \the [src] will initiate the DNA sampler. If there is no registered owner, a DNA sample \
						 will be taken and holder will be registered as the new owner. If [src] is already registered and DNA matches, \
						 the current firemode will be reported.\n\
						 \n\
						 It is also possible to register and unregister the owner via context menu (RMB on \the [src]) or a verb in the \
						 Object tab."

	display = new(src)
	vis_contents += display

	if(firemodes)
		// feedback set to false so newly spawned lawgivers don't immediately play effects and produce audible messages
		switch_firemodes(firemodes[1], feedback = FALSE)

/obj/item/gun/energy/lawgiver/Destroy()
	QDEL_NULL(display)
	return ..()

/obj/item/gun/energy/lawgiver/update_icon()
	. = ..()
	if(registered_owner_dna || emagged)
		display.icon_state = "lawgiver_display_overlay_[firemodes[sel_mode].name]"
	else
		display.icon_state = "lawgiver_display_overlay_disabled"

	overlays.Cut()
	if(power_supply)
		overlays += mag_overlay_icon_state
	if(flashlight_enabled)
		overlays += flashlight_overlay_icon_state

/obj/item/gun/energy/lawgiver/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/card/id))
		if(emagged)
			to_chat(user, SPAN("notice", "You swipe your [I], but nothing happens."))
			return
		to_chat(user, SPAN("notice", "You swipe your [I], initiating the DNA sampler of \the [src]."))
		register_owner()
		return
	if(istype(I, /obj/item/cell/magazine/lawgiver))
		load_cell(I, user)
		return
	if(istype(I, /obj/item/cell))
		to_chat(user, SPAN("warning", "\The [src]'s power connector is not compatible with \the [I]."))
		return
	if(istype(I, /obj/item/device/multitool))
		multitool_hack(I, user)
	return ..()

/obj/item/gun/energy/lawgiver/attack_self()
	flashlight_enabled = !flashlight_enabled
	if(flashlight_enabled)
		set_light(flashlight_max_bright, flashlight_inner_range, flashlight_outer_range, flashlight_falloff_curve, flashlight_color)
	else
		set_light(0)

	if(flashlight_toggle_sound)
		playsound(src, flashlight_toggle_sound, 20, TRUE) // quiet as it's a small switch on a handgun
	update_icon()

/obj/item/gun/energy/lawgiver/attack_hand(mob/user)
	if(user.get_inactive_hand() == src && power_supply)
		unload_cell(user)
		return
	return ..()

/obj/item/gun/energy/lawgiver/hear_talk(mob/speaker, msg)
	if(!emagged)
		if(loc != speaker || !istype(speaker, /mob/living/carbon))
			return
		var/mob/living/carbon/holder = speaker
		if(!registered_owner_dna || holder.dna.unique_enzymes != registered_owner_dna)
			return
	// hacked lawgiver listens to everyone and everywhere since its ID system is broken

	msg = replace_characters(lowertext(msg), list("."="", "!"=""))
	for(var/datum/firemode/lawgiver/mode in firemodes)
		if(msg in mode.keywords)
			switch_firemodes(mode)

/obj/item/gun/energy/lawgiver/switch_firemodes(datum/firemode/lawgiver/new_mode, feedback = TRUE)
	if(!istype(new_mode))
		return
	for(var/i in 1 to firemodes.len)
		if(firemodes[i]?.name == new_mode.name)
			sel_mode = i
	new_mode.apply_to(src)
	if(feedback)
		spawn(0.4 SECONDS)
			report_firemode()
	update_icon()

/obj/item/gun/energy/lawgiver/proc/load_cell(obj/item/cell/magazine/lawgiver/I, mob/user)
	if(power_supply)
		to_chat(user, SPAN("warning", "\The [src] already has \a [power_supply] installed."))
		return
	if(!istype(user))
		return
	if(!user.drop(I, src))
		return
	power_supply = I
	playsound(src, reload_sound, 75, FALSE)
	update_icon()

/obj/item/gun/energy/lawgiver/proc/unload_cell(mob/user)
	if(!power_supply)
		return
	if(!istype(user))
		return
	user.pick_or_drop(power_supply)
	power_supply = null
	playsound(src, unload_sound, 75, TRUE)
	update_icon()

/obj/item/gun/energy/lawgiver/AltClick()
	if(!registered_owner_dna && !emagged)
		register_owner()
		return
	if(!dna_check())
		id_fail_action()
		return
	report_firemode()

/obj/item/gun/energy/lawgiver/proc/report_firemode()
	var/datum/firemode/lawgiver/current_firemode = firemodes[sel_mode]
	if(!istype(current_firemode))
		return
	var/firemode_name = uppertext(current_firemode.name)
	audible_message("<b>\The [src]</b> reports, \"[firemode_name]\"", runechat_message = firemode_name)
	if(current_firemode.activation_sound)
		playsound(src, current_firemode.activation_sound, 75)

/obj/item/gun/energy/lawgiver/verb/submit_dna_sample()
	set name = "Submit DNA sample"
	set category = "Object"
	set src in usr
	register_owner()

/obj/item/gun/energy/lawgiver/verb/erase_dna_sample()
	set name = "Erase DNA sample"
	set category = "Object"
	set src in usr
	reset_owner()

/obj/item/gun/energy/lawgiver/proc/update_verbs()
	if(emagged)
		verbs -= /obj/item/gun/energy/lawgiver/verb/submit_dna_sample
		verbs -= /obj/item/gun/energy/lawgiver/verb/erase_dna_sample
		return
	if(registered_owner_dna)
		verbs += /obj/item/gun/energy/lawgiver/verb/erase_dna_sample
		verbs -= /obj/item/gun/energy/lawgiver/verb/submit_dna_sample
	else
		verbs += /obj/item/gun/energy/lawgiver/verb/submit_dna_sample
		verbs -= /obj/item/gun/energy/lawgiver/verb/erase_dna_sample

/obj/item/gun/energy/lawgiver/proc/register_owner()
	if(!istype(loc, /mob/living/carbon))
		if(registered_owner_dna)
			to_chat(usr, SPAN("notice", "\The [src] is already registered and just beeps."))
			beep_and_blink()
			return
		to_chat(usr, SPAN("warning", "\The [src] must be held in hands to register."))
		beep_and_blink()
		return

	if(registered_owner_dna)
		if(!dna_check())
			id_fail_action()
			return
		to_chat(usr, SPAN("notice", "\The [src] is already registered and just beeps."))
		beep_and_blink()
		return

	var/mob/living/carbon/H = loc
	registered_owner_dna = H.dna.unique_enzymes
	to_chat(usr, SPAN("notice", "You submit your DNA to \the [src]."))
	effects_id_check_ok()
	update_verbs()
	update_icon()

/obj/item/gun/energy/lawgiver/proc/reset_owner()
	if(!registered_owner_dna)
		to_chat(usr, SPAN("notice", "\The [src] is already unregistered."))
		return

	if(!istype(loc, /mob/living/carbon))
		to_chat(usr, SPAN("warning", "\The [src] must be held in hands to reset DNA."))
		beep_and_blink()
		return

	if(!dna_check())
		id_fail_action()
		return

	registered_owner_dna = null
	audible_message("<b>\The [src]</b> reports, \"I.D. RESET\"", runechat_message = "I.D. RESET")
	triple_beep_and_blink()
	update_verbs()
	update_icon()

/obj/item/gun/energy/lawgiver/special_check()
	if(emagged)
		return ..()
	if(!registered_owner_dna)
		audible_message("<b>\The [src]</b> reports, \"I.D. NOT SET\"", runechat_message = "I.D. NOT SET")
		triple_beep_and_blink()
		return
	if(!dna_check())
		id_fail_action()
		return FALSE
	return ..()

/obj/item/gun/energy/lawgiver/proc/dna_check()
	if(emagged)
		return TRUE // everyone's welcome
	if(!registered_owner_dna)
		return FALSE
	if(!istype(loc, /mob/living/carbon))
		return FALSE
	var/mob/living/carbon/holder = loc
	return registered_owner_dna == holder.dna.unique_enzymes

/obj/item/gun/energy/lawgiver/proc/id_fail_action()
	effects_id_check_fail()
	spawn(3.5 SECONDS)
		if(!istype(loc, /mob/living/carbon))
			return
		var/mob/living/carbon/user = loc
		if(electrocute_mob(user, src.power_supply, src))
			var/datum/effect/effect/system/spark_spread/spark = new /datum/effect/effect/system/spark_spread()
			spark.set_up(5, 0, src)
			spark.start()

/obj/item/gun/energy/lawgiver/emp_act()
	. = ..()
	switch_firemodes(pick(firemodes))

/obj/item/gun/energy/lawgiver/emag_act(remaining_charges, mob/user, emag_source)
	if(emagged || !remaining_charges)
		to_chat(user, SPAN("notice", "You swipe your [emag_source] through \the [src], but nothing happens."))
		return NO_EMAG_ACT
	get_hacked()
	return 1

/obj/item/gun/energy/lawgiver/proc/multitool_hack(obj/item/device/multitool/mt, mob/user)
	if(!istype(mt))
		CRASH("lawgiver multitool_hack() called with wrong tool: expected /obj/item/device/multitool, got [mt.type] ([mt])")
	if(emagged)
		to_chat(user, SPAN("warning", "You check the wiring of \the [src] and find the ID system already fried!"))
		return
	if(mt.in_use)
		to_chat(user, SPAN("warning", "This multitool is already in use!"))
		return
	mt.in_use = 1
	// Rolling twice in favor of the player to keep things fun and fast, no need to keep them waiting too long.
	// They already put in the effort to steal the gun and find a multitool.
	var/required_attempts = min(rand(3, 10), rand(3, 10))
	for(var/i in 1 to required_attempts)
		user.visible_message(SPAN("warning", "[user] picks in the wires of \the [src] with a multitool."),
							 SPAN("warning", "Attempting to short circuit the ID system... ([i])"))
		// 12 seconds per attempt gives us 2 minutes in the worst case scenario, matching with breaking out of handcuffs
		if(!do_after(user, 120))
			to_chat(user, SPAN("warning", "You stop manipulating the ID system of \the [src] and it resets itself into a working state!"))
			mt.in_use = 0
			return
		if(i == 5 && required_attempts > 5)
			to_chat(user, SPAN("warning", "Your attempts to crash the ID system caused a failsafe ciruit to activate. \
										   This will take some additional time to bypass."))
	get_hacked()
	mt.in_use = 0
	user.visible_message(SPAN("warning", "[user] short ciruits ID system of \the [src] with a multitool."),
						 SPAN("warning", "You short circuit the ID system of \the [src]."))

/obj/item/gun/energy/lawgiver/proc/get_hacked()
	emagged = 1
	registered_owner_dna = null
	update_verbs()
	effects_hacked()
	update_icon()

/obj/item/gun/energy/lawgiver/proc/beep_and_blink()
	playsound(src, 'sound/effects/weapons/energy/lawgiver/beep.ogg', 75)
	flick("lawgiver_indicator_blink", src)

/obj/item/gun/energy/lawgiver/proc/triple_beep_and_blink()
	playsound(src, 'sound/effects/weapons/energy/lawgiver/triple_beep.ogg', 75)
	flick("lawgiver_indicator_blink_triple", src)

// NOTE: sound effects and animations are 3.5 seconds long
/obj/item/gun/energy/lawgiver/proc/effects_id_check_ok()
	// sound effect
	playsound(src, 'sound/effects/weapons/energy/lawgiver/id_check.ogg', 60)
	// speech
	audible_message("<b>\The [src]</b> reports, \"DNA CHECK\"", runechat_message = "DNA CHECK")
	spawn(2 SECONDS)
		// delayed to match the audio effect and simulate ID being processed
		audible_message("<b>\The [src]</b> reports, \"I.D. OK\"", runechat_message = "I.D. OK")
	// indicator blinking sequence, part of the lawgiver sprite
	flick("lawgiver_indicator_blink_id_check_ok", src)
	// display animation
	display.id_check_ok_animation()

/obj/item/gun/energy/lawgiver/proc/effects_id_check_fail()
	// sound effect
	playsound(src, 'sound/effects/weapons/energy/lawgiver/id_check.ogg', 60)
	// speech
	audible_message("<b>\The [src]</b> reports, \"DNA CHECK\"", runechat_message = "DNA CHECK")
	spawn(2 SECONDS)
		// delayed to match the audio effect and simulate ID being processed
		audible_message("<b>\The [src]</b> reports, \"I.D. FAIL\"", runechat_message = "I.D. FAIL")
	// indicator blinking sequence, part of the lawgiver sprite
	flick("lawgiver_indicator_blink_id_check_fail", src)
	// display animation
	display.id_check_fail_animation()

/obj/item/gun/energy/lawgiver/proc/effects_hacked()
	// sound effect
	playsound(src, 'sound/effects/weapons/energy/lawgiver/hacked.ogg', 60)
	// speech
	audible_message("<b>\The [src]</b> reports, \"DNA CHECK-K-K\"", runechat_message = "DNA CHECK-K-K")
	spawn(1.5 SECONDS)
		audible_message("<b>\The [src]</b> reports, \"I.D. RE-OK-RE-\"", runechat_message = "I.D. RE-OK-RE-")
	spawn(2 SECONDS)
		audible_message("<b>\The [src]</b> reports, \"I.D. RESET\"", runechat_message = "I.D. RESET")
	// indicator blinking sequence, part of the lawgiver sprite
	flick("lawgiver_indicator_blink_hacked", src)
	// display animation
	display.hacked_animation()
