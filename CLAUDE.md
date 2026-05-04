# WhisperDictation

Native macOS Menubar-App für systemweite Sprach-Diktierung via Groq Whisper.

## Workflow

Bei Änderungen an dieser App folge dem Feature-Request-Workflow: [docs/feature-request-workflow.md](docs/feature-request-workflow.md). Niemals direkt auf `main` committen, sondern immer über `feature/<slug>`-Branches arbeiten und mit `--no-ff` mergen. Beta-Tests laufen auf einer parallel installierten App `/Applications/WhisperDictation Beta.app`.

## Build

- `./scripts/build-release.sh` für Production (ZIP + DMG)
- `./scripts/build-release.sh --beta` für Beta-Variante (installiert direkt nach `/Applications/WhisperDictation Beta.app`)
- `./scripts/release.sh <version> "<notes>"` für offizielles Release (Sparkle-Update für das Team)

`project.yml` ist eine Vorlage mit `${WD_*}`-Platzhaltern. `tools/render-project-yml.sh` rendert sie zu `project.generated.yml`, die xcodegen konsumiert. Direkt `xcodegen generate` aufzurufen würde ein kaputtes Projekt erzeugen.

## Doku

- [docs/feature-request-workflow.md](docs/feature-request-workflow.md): Feature-Wunsch-Prozess
- [docs/feature-request-workflow-setup-plan.md](docs/feature-request-workflow-setup-plan.md): Setup-Plan, der den Workflow live geschaltet hat
- [docs/release-workflow.md](docs/release-workflow.md): Sammel-Release-Prozess
- [docs/dev-workflow.md](docs/dev-workflow.md): End-to-End-Dev-Setup
- [docs/onboarding-team.md](docs/onboarding-team.md): Team-Installations-Anleitung
