# Guide des Règles Chifa

Ce document est la version lisible par l'homme des règles définies dans `.agents/context/agents-rules.json`.

## Identité du Projet

- **Nom**: Chifa
- **Nature**: Application de gestion de clinique (Desktop & Mobile).
- **Philosophie**: Architecture hybride local-cloud. L'application utilise XAMPP (MySQL local) sur Desktop pour la rapidité et Octenium/Railway (MySQL distant) pour la synchronisation et l'accès mobile.

## Règles d'Architecture

### Niveaux de Modification
- **L1 (Libre)**: Interfaces utilisateur (screens), Cubits (State Management), Thèmes.
- **L2 (Conditionnel)**: Repositories, Services de formatage, Génération de PDF. Attention à la cohérence des données.
- **L3 (Direct)**: Cœur du système de base de données (`database_manager.dart`, `sync_manager.dart`). Toute modification ici nécessite une documentation complète et des tests rigoureux.

### Protection
- Le répertoire `lib/services/db/` est sensible car il gère la synchronisation bidirectionnelle.
- Les commentaires sont obligatoires pour expliquer la logique métier complexe.

## Flux de Travail de l'IA
L'IA doit toujours vérifier l'état de la connexion et s'assurer que les colonnes de synchronisation (`uuid`, `needs_sync`, `updated_at`) sont respectées lors de la modification des modèles de données.

## Workflows Disponibles
- **Impression**: Gestion des PDF et prévisualisation.
- **Base de Données**: Migrations et logique de synchronisation.
