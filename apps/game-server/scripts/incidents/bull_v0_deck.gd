class_name BullV0Deck
extends RefCounted

const CARDS: Array[Dictionary] = [
    {
        "card_id": "bull_gain_eva_2",
        "card_text": "Receba 2 EVA.",
        "effect": "balance_delta",
        "fiat_delta": 2.0,
        "btc_delta": 0.0,
    },
    {
        "card_id": "bull_gain_btc_0_2",
        "card_text": "Receba 0.2 BTC.",
        "effect": "balance_delta",
        "fiat_delta": 0.0,
        "btc_delta": 0.2,
    },
    {
        "card_id": "bull_free_inspection_exit",
        "card_text": "Ganhe uma saida livre da inspecao.",
        "effect": "grant_inspection_voucher",
    },
]
