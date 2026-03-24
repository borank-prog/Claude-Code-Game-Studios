## Modern operasyon birimleri veri kaynagi.
## UnitManager bu veriyi kiralama/bonus hesaplama icin kullanir.
extends Node

const UNITS: Dictionary = {
	"crypto_launderer": {
		"name": "Kripto Aklayici",
		"description": "Kirli parayi zincir ustunde temizler. Gorev gelirini artirir, magazadaki vergi kesintisini sifirlar.",
		"type": "economy",
		"rarity": "EPIC",
		"required_rank": 3,
		"hire_cost": 5000,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "mission_cash_multiplier", "bonus_mode": "multiplier", "bonus_value": 1.15},
			{"bonus_type": "shop_tax_multiplier", "bonus_mode": "multiplier", "bonus_value": 0.0},
		],
	},
	"dark_web_influencer": {
		"name": "Yeralti Fenomeni",
		"description": "Mekanlara gorunmeden trafik ceker. Pasif bina gelirlerini ciddi sekilde buyutur.",
		"type": "economy",
		"rarity": "RARE",
		"required_rank": 5,
		"hire_cost": 8000,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "building_income_multiplier", "bonus_mode": "multiplier", "bonus_value": 1.40},
		],
	},
	"corrupt_customs": {
		"name": "Gumruk Musaviri",
		"description": "Karaborsa lojistigini kolaylastirir. Silah ve mal aliminda ekstra indirim saglar.",
		"type": "economy",
		"rarity": "RARE",
		"required_rank": 6,
		"hire_cost": 9000,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "black_market_discount_rate", "bonus_mode": "additive", "bonus_value": 0.20},
		],
	},
	"drone_operator": {
		"name": "Drone Pilotu",
		"description": "Baskinlarda havadan kesif yapar. Hedef savunma gucunu yumusatir.",
		"type": "operations",
		"rarity": "EPIC",
		"required_rank": 7,
		"hire_cost": 8500,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "raid_enemy_defense_multiplier", "bonus_mode": "multiplier", "bonus_value": 0.90},
		],
	},
	"the_insider": {
		"name": "Kostebek Komiser",
		"description": "Iceriden bilgi sizdirir. Heat artisini ve olasi hapis suresini dusurur.",
		"type": "operations",
		"rarity": "LEGENDARY",
		"required_rank": 9,
		"hire_cost": 15000,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "heat_gain_multiplier", "bonus_mode": "multiplier", "bonus_value": 0.50},
			{"bonus_type": "jail_time_multiplier", "bonus_mode": "multiplier", "bonus_value": 0.50},
		],
	},
	"the_cleaner": {
		"name": "Golge",
		"description": "Yuksek riskli VIP operasyonlarin basari sansini yukselten profesyonel.",
		"type": "operations",
		"rarity": "LEGENDARY",
		"required_rank": 10,
		"hire_cost": 18000,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "vip_success_add", "bonus_mode": "additive", "bonus_value": 0.12},
		],
	},
	"chemist": {
		"name": "Kimyager",
		"description": "Ekibin toparlanma hizini artirir. Stamina yenilenmesini hizlandirir.",
		"type": "support",
		"rarity": "RARE",
		"required_rank": 0,
		"hire_cost": 7000,
		"max_count": 1,
		"bonuses": [
			{"bonus_type": "stamina_regen_interval_multiplier", "bonus_mode": "multiplier", "bonus_value": 0.60},
		],
	},
}


func has_unit(unit_id: String) -> bool:
	return UNITS.has(unit_id)


func get_unit_data(unit_id: String) -> Dictionary:
	return UNITS.get(unit_id, {})


func get_all_units() -> Dictionary:
	return UNITS
