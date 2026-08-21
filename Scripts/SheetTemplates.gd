extends Node

const TEMPLATES = {
	"dnd_5e": {
		"system_name": "D&D 5e",
		"dice_logic": "d20_high", 
		"layout": [
			{"tab": "Identity", "elements": [
				{"type": "image", "label": "Appearance", "key": "portrait"},
				{"type": "text", "label": "Character Name", "key": "name"},
				{"type": "text", "label": "Class & Level", "key": "class"},
				{"id": "owner_id", "type": "text", "label": "Assigned Player Name:"},
				{"type": "long_text", "label": "Backstory", "key": "backstory"}
			]},
			
			{"tab": "Core", "elements": [
				{"type": "stat_row", "stats": ["STR", "DEX", "CON", "INT", "WIS", "CHA"]},
				{"type": "stat_box", "label": "Proficiency Bonus", "key": "prof_bonus"},
				{"type": "stat_box", "label": "Initiative Bonus", "key": "init_bonus"},
				{"type": "resource_bar", "label": "Hit Points", "max_key": "max_hp", "current_key": "hp"},
				{"type": "resource_bar", "label": "Temp HP", "max_key": "temp_hp_max", "current_key": "temp_hp"},
				{"type": "stat_box", "label": "Armor Class", "key": "armor_class"},
				{"type": "stat_box", "label": "Speed", "key": "speed"},
				# Requires a new UI component for checkboxes
				{"type": "death_saves", "label": "Death Saves", "success_key": "death_successes", "fail_key": "death_failures"} 
			]},
			
			{"tab": "Saves & Skills", "elements": [
				{"type": "skill_list", "label": "Saving Throws", "skills": [
					"STR Save", "DEX Save", "CON Save", "INT Save", "WIS Save", "CHA Save"
				]},
				{"type": "skill_list", "label": "Skills", "skills": [
					"Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception", 
					"History", "Insight", "Intimidation", "Investigation", "Medicine", 
					"Nature", "Perception", "Performance", "Persuasion", "Religion", 
					"Sleight of Hand", "Stealth", "Survival"
				]}
			]},
			
			{"tab": "Combat & Gear", "elements": [
				{"type": "long_text", "label": "Weapons & Attacks", "key": "weapons_text"},
				{"type": "long_text", "label": "Equipment & Inventory", "key": "inventory_text"},
				{"type": "stat_box", "label": "Copper", "key": "cp"},
				{"type": "stat_box", "label": "Silver", "key": "sp"},
				{"type": "stat_box", "label": "Gold", "key": "gp"}
			]},
			
			{"tab": "Notes", "elements": [
				{"type": "long_text", "label": "Features & Traits", "key": "features_text"},
				{"type": "long_text", "label": "Biography", "key": "bio_text"}
			]}
		]
	},
	
	"delta_green": {
		"system_name": "Delta Green",
		"dice_logic": "d100_under", 
		"layout": [
			{"tab": "Identity", "elements": [
				{"type": "image", "label": "Appearance", "key": "portrait"},
				{"type": "text", "label": "Character Name", "key": "name"},
				{"type": "text", "label": "Class & Level", "key": "class"},
				{"id": "owner_id", "type": "text", "label": "Assigned Player Name:"},
				{"type": "long_text", "label": "Backstory", "key": "backstory"}
			]},
			
			{"tab": "Agent", "elements": [
				{"type": "stat_row", "stats": ["STR", "CON", "DEX", "INT", "POW", "CHA"]},
				{"type": "resource_bar", "label": "Hit Points (HP)", "max_key": "max_hp", "current_key": "hp"},
				{"type": "resource_bar", "label": "Willpower (WP)", "max_key": "max_wp", "current_key": "wp"},
				{"type": "resource_bar", "label": "Sanity (SAN)", "max_key": "max_san", "current_key": "san"},
				{"type": "stat_box", "label": "Breaking Point (BP)", "key": "bp"}
			]},
			
			{"tab": "Skills", "elements": [
				{"type": "d100_skill_list", "label": "Standard Skills", "skills": [
					"Accounting", "Alertness", "Anthropology", "Archeology", "Art", 
					"Artillery", "Athletics", "Bureaucracy", "Computer Science", "Craft", 
					"Criminology", "Demolitions", "Disguise", "Dodge", "Drive", 
					"Firearms", "First Aid", "Forensics", "Heavy Machinery", "Heavy Weapons", 
					"History", "Law", "Medicine", "Melee Weapons", "Military Science", 
					"Navigate", "Occult", "Persuade", "Pharmacy", "Pilot", 
					"Psychotherapy", "Ride", "Science", "Search", "SIGINT", 
					"Stealth", "Surgery", "Survival", "Swim", "Unarmed Combat", "Unnatural"
				]}
			]},
			
			{"tab": "Psychological", "elements": [
				{"type": "long_text", "label": "Bonds", "key": "bonds_text"},
				{"type": "long_text", "label": "Motivations & Mental Disorders", "key": "disorders_text"},
				{"type": "long_text", "label": "Incidents of SAN Loss", "key": "san_loss_text"}
			]},
			{"tab": "Gear", "elements": [
				{"type": "long_text", "label": "Weapons & Lethality", "key": "weapons_text"},
				{"type": "long_text", "label": "Special Equipment", "key": "equipment_text"}
			]}
		]
	},
	
	"shinobigami": {
		"system_name": "Shinobigami",
		"dice_logic": "2d6_high", # Shinobigami uses 2d6 >= Target Number
		"layout": [
			{"tab": "Identity", "elements": [
				{"type": "image", "label": "Appearance", "key": "portrait"},
				{"type": "text", "label": "Character Name", "key": "name"},
				{"type": "text", "label": "Class & Level", "key": "class"},
				{"id": "owner_id", "type": "text", "label": "Assigned Player Name:"},
				{"type": "long_text", "label": "Backstory", "key": "backstory"}
			]},
			
			{"tab": "Profile", "elements": [
				{"type": "stat_row", "stats": ["Age", "Gender", "Rank"]},
				{"type": "text", "label": "Clan", "key": "clan"},
				{"type": "text", "label": "Cover", "key": "cover"},
				{"type": "text", "label": "Conviction", "key": "conviction"},
				{"type": "text", "label": "Merit", "key": "merit"},
				{"type": "text", "label": "Clan Goal", "key": "clan_goal"},
				# The sheet ties Life Points to the 6 Category Titles[cite: 1]. 
				# A standard Resource Bar tracks the total.
				{"type": "resource_bar", "label": "Life Points", "max_key": "max_lp", "current_key": "lp"}
			]},
			
			{"tab": "Tech & Martial", "elements": [
				{"type": "skill_list", "label": "Tech", "skills": [
					"Engineering", "Pyromancy", "Hydromancy", "Acupuncture", 
					"Hidden Weapons", "Apparel", "Ropework", "Climbing", 
					"Torture", "Demolition", "Burrow"
				]},
				{"type": "skill_list", "label": "Martial Arts", "skills": [
					"Riding", "Ballistics", "Shuriken", "Sleight of Hand", 
					"Contortionism", "Footwork", "Speed", "Aerial Arts", 
					"Hand to Hand", "Blade", "Unholy Strength"
				]}
			]},
			
			{"tab": "Stealth & Scheming", "elements": [
				{"type": "skill_list", "label": "Stealth", "skills": [
					"Survival", "Infiltration", "Escape", "Interception", 
					"Ventriloquism", "Invisibility", "Disguise", "Olfaction", 
					"Multiplicity", "Concealment", "Sixth Sense"
				]},
				{"type": "skill_list", "label": "Scheming", "skills": [
					"Medicine", "Poison", "Trap", "Investigation", 
					"Bluff", "Inception", "Performance", "Seduction", 
					"Manipulation", "Rumor-mongering", "Finances"
				]}
			]},
			
			{"tab": "Strategy & Sorcery", "elements": [
				{"type": "skill_list", "label": "Strategy", "skills": [
					"Cooking", "Creature Mastery", "Nature", "Guerilla", 
					"Willpower", "Tactics", "Memory", "Analysis", 
					"Encryption", "Signal", "Contacts"
				]},
				{"type": "skill_list", "label": "Sorcery", "skills": [
					"Transformation", "Summoning", "Necromancy", "Barrier", 
					"Binding", "Kotodama", "Illusion", "Domination", 
					"Clairvoyance", "Possession", "Curse"
				]}
			]},
			
			{"tab": "Ninpo & Ohgi", "elements": [
				{"type": "long_text", "label": "Ninpo List (Name | Skill | Type | Range | Cost | Effect)", "key": "ninpo_text"},
				{"type": "long_text", "label": "Ohgi 1 (Name | Assigned Skill | Effect)", "key": "ohgi_1_text"},
				{"type": "long_text", "label": "Ohgi 2 (Name | Assigned Skill | Effect)", "key": "ohgi_2_text"}
			]},
			
			{"tab": "Gear & Bonds", "elements": [
				# Consumable Ninja Gear[cite: 1]
				{"type": "stat_row", "stats": ["Bead of Life", "Soma Pill", "Prayer Seal"]},
				{"type": "long_text", "label": "People / Bonds", "key": "bonds_text"}
			]}
		]
	},
	
	"Ark": {
		"system_name": "Arknights 5e (AK5e)",
		"dice_logic": "d20_high",
		"layout": [
			{
				"tab": "Identity",
				"elements": [
					{"type": "image", "label": "Operator File Photo", "key": "portrait"},
					{"type": "text", "label": "Codename", "key": "name"},
					{"type": "text", "label": "Branch & Level", "key": "class"},
					{"id": "owner_id", "type": "text", "label": "Assigned Player Name:"},
					{"type": "long_text", "label": "Clinical Analysis & Background", "key": "backstory"}
				]
			},
			{
				"tab": "Core",
				"elements": [
					{"type": "stat_row", "stats": ["STR", "DEX", "CON", "INT", "WIS", "CHA"]},
					{"type": "stat_box", "label": "Proficiency Bonus", "key": "prof_bonus"},
					{"type": "stat_box", "label": "Initiative Bonus", "key": "init_bonus"},
					{"type": "resource_bar", "label": "Hit Points", "max_key": "max_hp", "current_key": "hp"},
					{"type": "resource_bar", "label": "Oripathy Assimilation", "max_key": "max_assimilation", "current_key": "assimilation_level"},
					{"type": "stat_box", "label": "Armor Class", "key": "armor_class"},
					{"type": "stat_box", "label": "Deployment Speed", "key": "speed"},
					{"type": "death_saves", "label": "Death Saves", "success_key": "death_successes", "fail_key": "death_failures"}
				]
			},
			{
				"tab": "Saves & Skills",
				"elements": [
					{
						"type": "skill_list",
						"label": "Saving Throws",
						"skills": [
							"STR Save", "DEX Save", "CON Save", "INT Save", "WIS Save", "CHA Save"
						]
					},
					{
						"type": "skill_list",
						"label": "Skills",
						"skills": [
							"Acrobatics", "Animal Handling", "Originium Arts (Arcana)", "Athletics", "Deception",
							"History", "Insight", "Intimidation", "Investigation", "Medicine",
							"Nature", "Perception", "Performance", "Persuasion", "Terra Lore (Religion)",
							"Sleight of Hand", "Stealth", "Survival"
						]
					}
				]
			},
			{
				"tab": "Combat & Gear",
				"elements": [
					{"type": "long_text", "label": "Armaments & Arts", "key": "weapons_text"},
					{"type": "long_text", "label": "Tactical Inventory", "key": "inventory_text"},
					{"type": "stat_box", "label": "LMD (Lungmen Dollars)", "key": "lmd"},
					{"type": "stat_box", "label": "Orundum", "key": "orundum"},
					{"type": "stat_box", "label": "Suppressant Doses", "key": "suppressants"}
				]
			},
			{
				"tab": "Notes",
				"elements": [
					{"type": "long_text", "label": "Operator Talents & Features", "key": "features_text"},
					{"type": "long_text", "label": "Archive Records", "key": "bio_text"}
				]
			}
		]
	}
	
}
