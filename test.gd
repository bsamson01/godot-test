extends Panel

var f := Faction.new()
f.name = "Test Faction"
f.color = Color.RED
f.funds = 500
f.supplies = 1000
$FactionCard.set_faction(f)
