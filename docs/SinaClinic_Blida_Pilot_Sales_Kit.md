# SinaClinic par MedevSync — Kit Commercial & Pilote Blida / Alger

> **SinaClinic** *(par MedevSync — Gestion de Cabinet & Dossier Patient, compatible nomenclature CNAS/Chifa)*  
> *Logiciel indépendant — non affilié à la CNAS.*  
> Contact direct Blida & Alger : **WhatsApp / Tél `+213 660 67 52 79`** (`0660 67 52 79`) • **`support@medsina.com`**

---

## 1. Proposition de Valeur pour les Cabinets Médicaux (Blida & Alger)

Les cabinets de médecine générale et spécialisée en Algérie perdent chaque jour un temps considérable entre registres papier, ordonnances manuscrites peu lisibles et dossiers égarés lorsque la connexion 4G/ADSL tombe en panne.

**SinaClinic** résout ces blocages en 4 piliers concrets :
1. **100 % Hors-Ligne d'abord (SQLite local)** : Zéro dépendance à la connexion Internet. Même Wi-Fi coupé, l'ouverture du dossier patient, la recherche et la prescription restent instantanées (< 100 ms).
2. **Ordonnance DCI conforme en 20 secondes** : Base médicamenteuse locale avec DCI/noms commerciaux compatibles nomenclature CNAS/Chifa, posologies adultes/pédiatriques, impression propre A5/A4 sans rature.
3. **Portail Patient & Carte QR imprimable** : Le patient accède à ses documents autorisés sans appel téléphonique inutile au secrétariat.
4. **Souveraineté Totale des Données (Export 1-Clic)** : Vos données restent sur votre poste (SQLite chiffrable côté hôte). Export intégral immédiat au format **JSON + CSV Excel** (`ClinicDataExportService`) dans `Documents\SinaClinic_Exports`.

---

## 2. Posture Légale & Confidentialité (Loi 18-07 & Loi 25-11)

- **Propriété exclusive du médecin** : Toutes les données cliniques résident en priorité localement au cabinet ; aucun hébergement cloud imposé en mode autonome.
- **Portabilité garantie** : Le médecin peut extraire à tout moment l'ensemble des fiches patients, consultations, ordonnances, bilans et factures en JSON/CSV standard sans verrouillage fournisseur.
- **Séparation démonstration / production** : Les données d'essai Blida utilisent un identifiant isolé (`demo-blida-*`) nettoyable en 1 commande avant la mise en production du cabinet.
- *Mention de transparence réglementaire* : SinaClinic intègre une architecture local-first et des exports structurés favorisant la maîtrise des données au sens des bonnes pratiques issues de la **Loi 18-07** (telle que modifiée par la **Loi 25-11**). SinaClinic est un outil privé indépendant et **ne revendique pas de certification officielle ANPDP ni d'affiliation à la CNAS**.

---

## 3. Grille Tarifaire & Formules Pilotes (DZD)

| Formule | Cible | Abonnement Mensuel | Frais d'Installation & Formation sur Site | Inclus |
|---|---|---:|---:|---|
| **SinaClinic Solo** | Médecin généraliste ou spécialiste individuel | **3 500 DZD / mois** | **15 000 DZD** *(one-shot)* | 1 poste médecin + 1 poste accueil, SQLite hors-ligne, ordonnances, bilans, facturation, export 1-clic |
| **Cabinet Multi-Médecins** | Cabinet de groupe (2 à 4 praticiens) | **6 500 DZD / mois** | **25 000 DZD** *(one-shot)* | Multi-praticiens, file d'attente accueil, portail patient QR, sauvegardes & formation complète |
| **Polyclinique / Centre Médical** | Structures 5+ médecins | **12 000 DZD / mois** | **40 000 DZD** *(one-shot)* | Multi-services, rôles Admin/Médecin/Assistant, accompagnement déploiement prioritaire |

### Offre Fondateur Pilote Blida (5 Premiers Cabinets)
- **Essai Pilote 30 Jours** avec données réelles ou base de démonstration.
- **Installation physique sur site à Blida** en moins de 45 minutes + prise en main secrétariat.
- Engagement sans risque : si le cabinet ne poursuit pas au terme des 30 jours, export intégral gratuit des données saisies au format CSV/JSON.

---

## 4. ROI Comparatif vs. Registres Papier & Logiciels Dépendants d'Internet

| Critère | Registres Papier | Logiciel Web "Cloud-Only" | **SinaClinic par MedevSync** |
|---|---|---|---|
| Fonctionnement sans Internet | Oui | Bloqué dès coupure ADSL/4G | **Oui — 100 % SQLite Local** |
| Temps d'émission d'une ordonnance | 2 à 4 min | 30–60 s *(si réseau fluide)* | **20 secondes hors-ligne** |
| Retrouver un dossier ancien | 3 à 10 min | 5 s *(si connecté)* | **< 1 seconde hors-ligne** |
| Lisibilité pharmacie & patient | Manuscrite | Imprimée | **Imprimée A4/A5 + DCI** |
| Souveraineté & départ facile | Archives papier | Dépend du serveur tiers | **Export JSON/CSV en 1 clic** |
| Support local Blida / Alger | N/A | Ticket lent à distance | **Intervention directe +213 660 67 52 79** |

*Estimation gain cabinet (20 consultations/jour)* : ~2 minutes économisées par consultation et moins d'erreurs de recopie = **40 à 50 minutes récupérées par jour**, soit l'équivalent de **2 à 3 consultations supplémentaires possibles sans rallonger la journée**.

---

## 5. Script de Démonstration Live en 15 Minutes (« Wi-Fi Coupé »)

### Avant d'entrer au cabinet (Checklist 2 min)
1. Préparer la base démo avec `scripts/seed_blida_demo_clinic.py` (15 patients fictifs Blida, 15 consultations, 15 ordonnances DCI, 10 RDV, 10 factures).
2. **Désactiver le Wi-Fi devant le médecin** dès la minute 1 pour prouver le fonctionnement 100 % local.
3. Garder le **One-Pager imprimé** (`SinaClinic_OnePager_Security_ROI.html`) à portée de main.

### Déroulé minute par minute
- **00–02 min (Accroche terrain)** : Montrer l'écran déconnecté (Wi-Fi coupé). *"Docteur, si Algérie Télécom coupe pendant la matinée chargée, votre cabinet ne doit jamais s'arrêter."*
- **02–05 min (Accueil & File d'attente)** : Rechercher *"Benali"* ou *"Boufarik"* instantanément parmi les 15 dossiers de Blida ; ouvrir un dossier en < 1 seconde (constantes, allergies signalées en alerte comme *"Pénicilline"* ou *"AINS"*).
- **05–10 min (Consultation & Ordonnance DCI en 20s)** : Saisir une consultation, ajouter Amlodipine 5 mg ou Amoxicilline/Ac. Clavulanique 1 g, montrer l'aperçu PDF propre prêt à imprimer.
- **10–13 min (Portail Patient QR & Encaissement)** : Montrer la carte patient QR et le suivi des factures/encaissements du jour.
- **13–15 min (Souveraineté Export 1-Clic & Closing Pilote)** : Déclencher l'export JSON + CSV Excel et conclure : *"On l'installe chez vous sur votre PC d'accueil et de consultation en 30 jours pilote à Blida, avec vos propres données exportables à 100 % à tout moment."*

---

## 6. Réponses aux 6 Objections Fréquentes des Médecins

1. **« Et si Internet coupe dans mon cabinet ? »**  
   SinaClinic stocke la base active dans un SQLite local sur votre ordinateur. Aucune consultation ni ordonnance ne dépend d'Internet.
2. **« Et si mon ordinateur tombe en panne ? »**  
   L'export 1-clic crée une sauvegarde complète JSON + CSV lisible dans Excel (et copiable sur clé USB chaque fin de journée) en plus de la synchronisation optionnelle.
3. **« Est-ce que ça remplace la carte Chifa de la CNAS ? »**  
   Non, et nous sommes totalement transparents là-dessus : SinaClinic est un logiciel indépendant de gestion de cabinet compatible avec la nomenclature médicamenteuse algérienne, **non affilié à la CNAS**.
4. **« Mes patients et mes comptes restent-ils confidentiels ? »**  
   Oui : architecture prioritairement locale sur votre poste, contrôle d'accès par rôle (Médecin / Secrétariat / Admin) et aucun transfert obligé vers un tiers.
5. **« Mon assistante/secrétaire va-t-elle savoir l'utiliser ? »**  
   Oui : l'interface sépare clairement la réception (RDV, fiche patient, encaissement) de l'acte médical, et l'installation inclut une formation pratique de 45 min sur site.
6. **« Si j'arrête dans 3 mois, est-ce que je perds mes dossiers ? »**  
   Jamais : en un clic vous repartez avec l'intégralité de vos patients en fichier CSV Excel et vos dossiers complets en JSON.

---

## 7. Modèle de Convention d'Évaluation Pilote 30 Jours (Blida)

```text
CONVENTION D'ÉVALUATION PILOTE (30 JOURS) — SINACLINIC PAR MEDEVSYNC

Entre : MedevSync (Éditeur de SinaClinic) — Tél/WhatsApp : +213 660 67 52 79 — Email : support@medsina.com
Et le Cabinet Médical : Dr ______________________________________
Spécialité : __________________________ Adresse (Blida/Alger) : _________________________________

1. Objet : Mise à disposition à titre pilote du logiciel SinaClinic (mode local-first SQLite +
   export JSON/CSV) pour une durée de 30 jours calendaires à compter du ____/____/202__.
2. Installation & Accompagnement : Installation sur ____ poste(s) et formation pratique de 45 min.
3. Propriété & Réversibilité des Données : Le Cabinet demeure propriétaire exclusif de l'ensemble
   des données saisies. À tout moment et à l'issue du pilote, le Cabinet peut exporter l'intégralité
   de sa base en CSV et JSON via la fonction intégrée.
4. Transparence : SinaClinic est un logiciel indépendant non affilié à la CNAS. Il ne constitue ni
   un dispositif médical certifié ni une solution agréée ANPDP.
5. Suite du Pilote : À l'issue des 30 jours, le Cabinet choisit librement de poursuivre sous la
   formule ________________ (3 500 / 6 500 / 12 000 DZD/mois) ou d'arrêter sans pénalité.

Fait en deux exemplaires à __________________, le ____/____/202__.

Pour le Cabinet Médical (Cachet & Signature)         Pour MedevSync (Signature)
```
