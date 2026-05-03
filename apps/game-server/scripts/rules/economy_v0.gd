class_name EconomyV0
extends RefCounted

const INITIAL_FIAT_BALANCE: float = 130.0
const BTC_GOAL_TO_WIN: float = 20.0
const TOLL_RATE: float = 0.10

const PROPERTY_VALUES: Array[Dictionary] = [
    {"tile_index": 0, "city": "Irkutsk", "tile_type": "A", "buy_price": 34.0, "energy_production": 8, "sell_100_fiat": 4.0, "mine_100_btc": 0.75},
    {"tile_index": 1, "city": "Irkutsk", "tile_type": "B", "buy_price": 42.0, "energy_production": 10, "sell_100_fiat": 5.0, "mine_100_btc": 0.95},
    {"tile_index": 2, "city": "Irkutsk", "tile_type": "C", "buy_price": 50.0, "energy_production": 12, "sell_100_fiat": 6.0, "mine_100_btc": 1.15},
    {"tile_index": 3, "city": "Patagonia", "tile_type": "A", "buy_price": 28.0, "energy_production": 10, "sell_100_fiat": 3.0, "mine_100_btc": 0.45},
    {"tile_index": 4, "city": "Patagonia", "tile_type": "B", "buy_price": 36.0, "energy_production": 13, "sell_100_fiat": 4.0, "mine_100_btc": 0.60},
    {"tile_index": 5, "city": "Patagonia", "tile_type": "C", "buy_price": 44.0, "energy_production": 16, "sell_100_fiat": 5.0, "mine_100_btc": 0.75},
    {"tile_index": 6, "city": "Ciudad del Este", "tile_type": "A", "buy_price": 38.0, "energy_production": 9, "sell_100_fiat": 6.0, "mine_100_btc": 0.55},
    {"tile_index": 7, "city": "Ciudad del Este", "tile_type": "B", "buy_price": 46.0, "energy_production": 12, "sell_100_fiat": 8.0, "mine_100_btc": 0.70},
    {"tile_index": 8, "city": "Ciudad del Este", "tile_type": "C", "buy_price": 54.0, "energy_production": 15, "sell_100_fiat": 10.0, "mine_100_btc": 0.85},
    {"tile_index": 9, "city": "El Salvador", "tile_type": "A", "buy_price": 32.0, "energy_production": 8, "sell_100_fiat": 4.0, "mine_100_btc": 0.65},
    {"tile_index": 10, "city": "El Salvador", "tile_type": "B", "buy_price": 40.0, "energy_production": 11, "sell_100_fiat": 6.0, "mine_100_btc": 0.85},
    {"tile_index": 11, "city": "El Salvador", "tile_type": "C", "buy_price": 48.0, "energy_production": 14, "sell_100_fiat": 8.0, "mine_100_btc": 1.05},
    {"tile_index": 12, "city": "Angra dos Reis", "tile_type": "A", "buy_price": 44.0, "energy_production": 11, "sell_100_fiat": 8.0, "mine_100_btc": 0.60},
    {"tile_index": 13, "city": "Angra dos Reis", "tile_type": "B", "buy_price": 54.0, "energy_production": 14, "sell_100_fiat": 11.0, "mine_100_btc": 0.80},
    {"tile_index": 14, "city": "Angra dos Reis", "tile_type": "C", "buy_price": 64.0, "energy_production": 17, "sell_100_fiat": 14.0, "mine_100_btc": 1.00},
    {"tile_index": 15, "city": "Atacama", "tile_type": "A", "buy_price": 24.0, "energy_production": 9, "sell_100_fiat": 2.0, "mine_100_btc": 0.35},
    {"tile_index": 16, "city": "Atacama", "tile_type": "B", "buy_price": 32.0, "energy_production": 12, "sell_100_fiat": 3.0, "mine_100_btc": 0.50},
    {"tile_index": 17, "city": "Atacama", "tile_type": "C", "buy_price": 40.0, "energy_production": 15, "sell_100_fiat": 4.0, "mine_100_btc": 0.65},
]


static func property_values_for_tile(tile_index: int) -> Dictionary:
    assert(tile_index >= 0 and tile_index < PROPERTY_VALUES.size())
    var values: Dictionary = PROPERTY_VALUES[tile_index].duplicate(true)
    values["toll"] = toll_for_price(float(values.get("buy_price", 0.0)))
    return values


static func toll_for_price(buy_price: float) -> float:
    return buy_price * TOLL_RATE
