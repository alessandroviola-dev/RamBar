# RamBar audit

Data: 2026-10-06

## Esito

Audit del progetto completato: nessun problema critico rilevato. Il progetto è adatto a una beta release. `swift test` passa senza fallimenti e non sono stati trovati segreti, credenziali o path utente hardcoded nei file versionati.

## Aree verificate

- Struttura SwiftPM e separazione dei componenti
- Calcolo della memoria tramite Mach VM statistics
- Formattazione e gestione dei valori limite
- Lifecycle del timer e wake observer
- Installazione, aggiornamento e disinstallazione
- Bundle metadata e privacy manifest
- Build e workflow GitHub Actions
- Ricerca di segreti e path locali

## Modifiche applicate

- `MemoryMonitor.start()` ora resetta lo stato di rendering quando il monitor viene riavviato.
- Aggiunta la categoria `public.app-category.utilities` al bundle.
- Documentati nel README macOS minimo, requisito Apple Silicon e natura stimata della percentuale.
- Aggiunti lint Bash e ShellCheck al workflow CI di release.

## Limitazioni residue

- La build attuale è `arm64` e non supporta Mac Intel.
- Gli artifact sono firmati ad-hoc e non sono ancora notarizzati con Developer ID.
- I test automatici coprono soprattutto il calcolo della memoria; menu, login item e wake/sleep restano da verificare manualmente.

## Raccomandazioni future

1. Configurare firma Developer ID e notarizzazione Apple.
2. Aggiungere verifica `spctl --assess` alla pipeline dopo la notarizzazione.
3. Valutare una build universal se serve il supporto Intel.
4. Aggiungere test per menu, Launch at Login e gestione degli errori UI.
5. Generare checksum SHA-256 per gli ZIP pubblicati.
