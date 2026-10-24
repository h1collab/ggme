extends RefCounted
# Local cosmetic progression. Paid ownership is never inferred from a save file.
const ID := "S1"
const MAX_LEVEL := 45
const XP_PER_LEVEL := 100
const PROFILE := "user://faceless2_s1.cfg"
var xp := 0
var tokens := 0
var claimed: Array[int] = []
var collection: PackedStringArray = []
var profile_path := PROFILE
var session := ""
var completed: Dictionary = {}
func level() -> int:
	return mini(MAX_LEVEL,1+xp/XP_PER_LEVEL)
func level_xp() -> int:
	return XP_PER_LEVEL if level() == MAX_LEVEL else xp%XP_PER_LEVEL
func reward(tier: int, paid: bool = false) -> Dictionary:
	if tier < 1 or tier > MAX_LEVEL: return {}
	if tier == 45: return {"kind":"title","name":"VOID CROWN" if paid else "S1 SURVIVOR","zh":"虚无之冠" if paid else "S1 生还者","amount":1}
	if tier%5 == 0: return {"kind":"badge","name":("VOID" if paid else "SIGNAL")+" / %02d" % tier,"zh":("虚无" if paid else "信号")+" / %02d" % tier,"amount":1}
	return {"kind":"tokens","name":"SIGNAL TOKENS","zh":"信号徽记","amount":(120 if paid else 50)+tier*5}
func state(tier: int, paid: bool = false) -> String:
	if paid: return "PAID_LOCKED"
	if claimed.has(tier): return "CLAIMED"
	return "AVAILABLE" if tier <= level() else "LEVEL_LOCKED"
func claim(tier: int, paid: bool = false) -> String:
	var status := state(tier,paid)
	if tier < 1 or tier > MAX_LEVEL: return "INVALID"
	if status != "AVAILABLE": return status
	var entry := reward(tier,false)
	claimed.append(tier)
	if entry.kind == "tokens": tokens += int(entry.amount)
	else: collection.append(str(entry.name))
	save_profile()
	return "CLAIMED"
func begin_session() -> void:
	session = Crypto.new().generate_random_bytes(8).hex_encode()
	completed.clear()
func record_round(round_id: int, winner: bool) -> bool:
	var key := session+":"+str(round_id)
	if session.is_empty() or completed.has(key): return false
	completed[key] = true
	add_xp(140 if winner else 100)
	return true
func add_xp(amount: int) -> void:
	xp = clampi(xp+maxi(0,amount),0,(MAX_LEVEL-1)*XP_PER_LEVEL)
	save_profile()
func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(profile_path) != OK: return
	xp = clampi(int(config.get_value(ID,"xp",0)),0,4400)
	tokens = maxi(0,int(config.get_value(ID,"tokens",0)))
	claimed.clear()
	for tier in config.get_value(ID,"claimed",[]):
		if tier is int and tier >= 1 and tier <= level() and not claimed.has(tier): claimed.append(tier)
	collection = PackedStringArray(config.get_value(ID,"collection",[]))
func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value(ID,"xp",xp)
	config.set_value(ID,"tokens",tokens)
	config.set_value(ID,"claimed",claimed)
	config.set_value(ID,"collection",collection)
	config.save(profile_path)
