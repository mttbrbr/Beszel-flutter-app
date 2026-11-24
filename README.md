# Beszel app

Client Flutter minimale per [Beszel](https://beszel.dev): connetti l'hub via IP (anche `http://`, es. Tailscale),
vedi i dispositivi e imposta trigger con notifiche locali (offline, CPU, RAM, disco, temperatura).

```bash
./setup.sh      # genera android/ios, abilita HTTP in chiaro, permessi, desugaring
flutter run
```

Le notifiche sono locali: l'app interroga l'hub ogni 20 s (aperta) e ogni ~15 min in background (WorkManager).
