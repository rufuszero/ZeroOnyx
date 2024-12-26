/obj/item/gun/energy/lawgiver
	name = "lawgiver"
	desc = "The Lawgiver II-E, an energy-based continuation of the unique Lawgiver series.\n\
	This advanced adaptive sidearm features mission-variable, voice-programmed ammunition, \
	with support for <b>stun, laser, rapid-fire, flash, and armor-piercing modes</b>.\n\
	Equipped with several security features, including a <b>DNA sensor</b> handgrip, it allows access \
	only to the operator it is registered to."
	icon_state = "lawgiver"
	origin_tech = list(TECH_COMBAT = 5, TECH_MATERIAL = 5, TECH_ENGINEERING = 5)
	screen_shake = 0
	cell_type = /obj/item/cell/magazine/lawgiver
	projectile_type = null
	firemodes = list(
		new /datum/firemode/lawgiver/stun,
		new /datum/firemode/lawgiver/laser,
		new /datum/firemode/lawgiver/rapid,
		new /datum/firemode/lawgiver/flash,
		new /datum/firemode/lawgiver/armorpierce)
	var/registered_owner_dna
	var/emagged = FALSE

/obj/item/gun/energy/lawgiver/Initialize()
	. = ..()
	update_verbs()

	GLOB.listening_objects += src

	description_info += "\n\n"
	var/firemode_keywords_info = "The following firemodes can be activated if registered operator speaks one of the keywords:\n\n"
	for(var/datum/firemode/lawgiver/mode in firemodes)
		firemode_keywords_info += "[capitalize(mode.name)] - [jointext(mode.keywords, ", ")]\n"
	description_info = description_info + firemode_keywords_info

	if(firemodes)
		switch_firemodes(firemodes[1])

/obj/item/gun/energy/lawgiver/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/card/id))
		if(emagged)
			to_chat(user, "You swipe your [I], but nothing happens.")
			return
		to_chat(user, "You swipe your [I], initiating the DNA sampler of \the [src].")
		register_owner()
		return
	..()

/obj/item/gun/energy/lawgiver/hear_talk(mob/speaker, msg)
	if(loc != speaker || !istype(speaker, /mob/living/carbon))
		return
	var/mob/living/carbon/holder = speaker
	if(!registered_owner_dna || holder.dna.unique_enzymes != registered_owner_dna)
		return

	msg = replace_characters(lowertext(msg), list("."="", "!"=""))
	for(var/datum/firemode/lawgiver/mode in firemodes)
		if(msg in mode.keywords)
			switch_firemodes(mode)

/obj/item/gun/energy/lawgiver/switch_firemodes(datum/firemode/lawgiver/new_mode)
	if(!istype(new_mode))
		return
	for(var/i in 1 to firemodes.len)
		if(firemodes[i]?.name == new_mode.name)
			sel_mode = i
	new_mode.apply_to(src)
	report_firemode()

/obj/item/gun/energy/lawgiver/attack_self()
	// TODO(rufus): attack_self action can and should be updated to the preference of active HoS players
	if(!registered_owner_dna)
		audible_message("<b>\The [src]</b> reports, \"I.D. NOT SET\"", runechat_message = "I.D. NOT SET")
		playsound(src, 'sound/effects/weapons/energy/lawgiver/triple_beep.ogg', 75)
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

/obj/item/gun/energy/lawgiver/AltClick()
	if(!registered_owner_dna)
		submit_dna_sample()
		return
	// TODO(rufus): AltClick action can and should be updated to the preference of active HoS players
	report_firemode()

/obj/item/gun/energy/lawgiver/verb/submit_dna_sample()
	set name = "Submit DNA sample"
	set category = "Object"
	set src in usr

	register_owner()
	update_verbs()

/obj/item/gun/energy/lawgiver/verb/erase_dna_sample()
	set name = "Erase DNA sample"
	set category = "Object"
	set src in usr

	reset_owner()
	update_verbs()

/obj/item/gun/energy/lawgiver/proc/update_verbs()
	if(registered_owner_dna)
		verbs += /obj/item/gun/energy/lawgiver/verb/erase_dna_sample
		verbs -= /obj/item/gun/energy/lawgiver/verb/submit_dna_sample
	else
		verbs += /obj/item/gun/energy/lawgiver/verb/submit_dna_sample
		verbs -= /obj/item/gun/energy/lawgiver/verb/erase_dna_sample

/obj/item/gun/energy/lawgiver/proc/register_owner()
	if(!istype(loc, /mob/living/carbon))
		if(registered_owner_dna)
			// if we're already registered, but are not held in hands, we can't do any DNA checks, just return
			return
		to_chat(usr, SPAN("notice", "\The [src] must be held in hands to register."))
		sound_beep()
		return

	if(registered_owner_dna)
		if(!dna_check())
			id_fail_action()
			return
		to_chat(usr, "\The [src] is already registered, nothing happens.")
		sound_beep()
		return

	var/mob/living/carbon/H = loc
	registered_owner_dna = H.dna.unique_enzymes
	to_chat(usr, SPAN("notice", "You submit your DNA to \the [src]."))
	audible_message("<b>\The [src]</b> reports, \"DNA CHECK\"", runechat_message = "DNA CHECK")
	playsound(src, 'sound/effects/weapons/energy/lawgiver/id_check.ogg', 60)
	spawn(1.5 SECOND)
		audible_message("<b>\The [src]</b> reports, \"I.D. OK\"", runechat_message = "I.D. OK")
	update_icon()

/obj/item/gun/energy/lawgiver/proc/reset_owner()
	if(!registered_owner_dna)
		to_chat(usr, SPAN("notice", "\The [src] is already unregistered."))
		return

	if(!istype(loc, /mob/living/carbon))
		to_chat(usr, SPAN("notice", "\The [src] must be held in hands to reset DNA."))
		sound_beep()
		return

	if(!dna_check())
		id_fail_action()
		return

	registered_owner_dna = null
	playsound(src, 'sound/effects/weapons/energy/lawgiver/triple_beep.ogg', 75)
	audible_message("<b>\The [src]</b> reports, \"I.D. RESET\"", runechat_message = "I.D. RESET")
	update_icon()

/obj/item/gun/energy/lawgiver/special_check()
	if(!registered_owner_dna)
		audible_message("<b>\The [src]</b> reports, \"I.D. NOT SET\"", runechat_message = "I.D. NOT SET")
		playsound(src, 'sound/effects/weapons/energy/lawgiver/triple_beep.ogg', 75)
		return
	if(!dna_check())
		id_fail_action()
		return FALSE
	return ..()

/obj/item/gun/energy/lawgiver/proc/dna_check()
	if(!registered_owner_dna)
		return FALSE
	if(!istype(loc, /mob/living/carbon))
		return FALSE
	var/mob/living/carbon/holder = loc
	return registered_owner_dna == holder.dna.unique_enzymes

/obj/item/gun/energy/lawgiver/proc/id_fail_action()
	audible_message("<b>\The [src]</b> reports, \"DNA CHECK\"", runechat_message = "DNA CHECK")
	playsound(src, 'sound/effects/weapons/energy/lawgiver/id_check.ogg', 60)
	spawn(1 SECOND)
		audible_message("<b>\The [src]</b> reports, \"I.D. FAIL\"", runechat_message = "I.D. FAIL")
	spawn(3 SECONDS)
		if(!istype(loc,/mob/living/carbon))
			return
		var/mob/living/carbon/user = loc
		if(electrocute_mob(user, src.power_supply, src))
			var/datum/effect/effect/system/spark_spread/spark = new /datum/effect/effect/system/spark_spread()
			spark.set_up(5, 0, src)
			spark.start()

/obj/item/gun/energy/lawgiver/proc/sound_beep()
	playsound(src, 'sound/effects/weapons/energy/lawgiver/beep.ogg', 75)

/obj/item/gun/energy/lawgiver/emp_act()
	. = ..()
	switch_firemodes(pick(firemodes))
