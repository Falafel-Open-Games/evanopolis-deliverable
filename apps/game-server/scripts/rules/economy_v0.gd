class_name EconomyV0
extends RefCounted

const INITIAL_FIAT_BALANCE: float = 120.0
const BTC_GOAL_TO_WIN: float = 21.0
const INSPECTION_FEE: float = 2.0
const MINER_BATCH_PRICE: float = 8.0
const MAX_MINER_BATCHES_PER_PROPERTY: int = 4
const MINER_BTC_PAYOUT_PER_BATCH: float = 2.0


static func base_property_price(city: String) -> float:
    if city == "Patagonia":
        return 3.0
    if city == "Ciudad del Este":
        return 4.0
    if city == "El Salvador":
        return 5.0
    if city == "Angra dos Reis":
        return 6.0
    if city == "Atacama":
        return 7.0
    if city == "Irkutsk":
        return 8.0
    assert(false)
    return 0.0
