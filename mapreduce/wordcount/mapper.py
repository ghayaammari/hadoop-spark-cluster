#!/usr/bin/env python3
"""
mapper.py - Hadoop Streaming MapReduce sur purchases.txt

Format de chaque ligne (séparé par tabulations) :
  date \t heure \t ville \t catégorie \t montant \t paiement

Ce mapper lit chaque ligne et émet : catégorie \t montant
"""

import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    fields = line.split("\t")

    # Vérifier qu'on a bien 6 colonnes
    if len(fields) < 6:
        continue

    category = fields[3]   # colonne 4 : catégorie
    amount   = fields[4]   # colonne 5 : montant

    try:
        float(amount)      # valider que c'est un nombre
        # Émettre : "Men's Clothing\t214.05"
        print(f"{category}\t{amount}")
    except ValueError:
        pass               # ligne mal formée → ignorer
