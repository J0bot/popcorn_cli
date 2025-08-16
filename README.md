# Popcorn CLI

C'est comme popcorn time ou stremio, mais en cli, pour les vrais nerds bien linux.

Version anime : ([ani-cli](https://github.com/pystardust/ani-cli))

Cette daube infinie m'a pris beaucoup trop de temps à faire.
ça fonctionne super bien mais franchement c'est pas fou pour ce que c'est.

---

## Install (Linux)

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/J0bot/popcorn_cli/refs/heads/master/installer.sh)"
```

Ce qu'il fait :

- Installe les dépendances système (git, curl, python3 + venv/pip, mpv, nodejs/npm)
- Installe `peerflix` (npm) en mode utilisateur (~/.local)
- Clone/Met à jour le repo sous `~/.local/share/popcorn_cli`
- Crée un lanceur `~/.local/bin/popcorn`

## Utilisation

```sh
popcorn
```

Si la commande n’est pas trouvée, ajoute `~/.local/bin` à ton PATH ou ouvre un nouveau terminal.

## Désinstallation

```sh
rm -rf ~/.local/share/popcorn_cli ~/.local/bin/popcorn
```

## Installation locale (dev)

```sh
git clone https://github.com/J0bot/popcorn_cli.git
cd popcorn_cli
sh ./installer.sh
popcorn
```

---

## Avertissement légal

- Projet fourni à des fins éducatives/démonstratives uniquement.
- Vous êtes seul responsable de votre usage. Utilisez-le uniquement pour des contenus pour lesquels vous avez les droits.
- Le dépôt n’héberge aucun contenu et n’est affilié à aucun service tiers (p. ex. YTS, peerflix, mpv).
- Le téléchargement/streaming peut être illégal selon votre juridiction. Vérifiez et respectez les lois locales et CGU.
- Logiciel fourni « en l’état », sans garantie expresse ou implicite. Aucune responsabilité ne pourra être engagée.

## Licence

Sous licence MIT — voir le fichier `LICENSE`.
