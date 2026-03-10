class_name BearV0Deck
extends RefCounted

const CARDS: Array[Dictionary] = [
    {
        "card_id": "bear_fine_eva_2",
        "card_text": "Pague 1 EVA.",
        "effect": "balance_delta",
        "fiat_delta": -1.0,
        "btc_delta": 0.0,
    },
    {
        "card_id": "bear_fine_eva_3",
        "card_text": "Pague 1.5 EVA.",
        "effect": "balance_delta",
        "fiat_delta": -1.5,
        "btc_delta": 0.0,
    },
    {
        "card_id": "bear_legal_inspection",
        "card_text": "Va para inspecao.",
        "effect": "send_to_inspection",
    },
]
