#!/usr/bin/env python3
"""
reducer.py - Hadoop Streaming MapReduce sur purchases.txt

Reçoit les paires triées : catégorie \t montant
Émet : catégorie \t total_ventes

Les données arrivent DÉJÀ TRIÉES par catégorie (sort phase Hadoop).
"""

import sys

current_category = None
current_total    = 0.0

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    parts = line.split("\t", 1)
    if len(parts) != 2:
        continue

    category, amount_str = parts

    try:
        amount = float(amount_str)
    except ValueError:
        continue

    # Quand la catégorie change → émettre le total de la précédente
    if category == current_category:
        current_total += amount
    else:
        if current_category is not None:
            print(f"{current_category}\t{current_total:.2f}")
        current_category = category
        current_total    = amount

# Émettre la dernière catégorie
if current_category is not None:
    print(f"{current_category}\t{current_total:.2f}")
