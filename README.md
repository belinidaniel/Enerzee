# Enerzee Salesforce Project

This repository stores Salesforce metadata and automation for Enerzee.

## Documentation Index

- Full metadata dependency map: `docs/project-dependencies-full.md`
- Opportunity -> Viability -> Project -> Installation baseline: `.codex/skills/salesforce-architect/references/project-metadata-baseline.md`
- Recommended default architecture pattern: `.codex/skills/salesforce-architect/references/default-architecture-pattern.md`
- Legacy Apex coverage export: `docs/apex-coverage-snapshot.md`

## Main Metadata Areas

- `force-app/main/default/objects`
- `force-app/main/default/classes`
- `force-app/main/default/triggers`
- `force-app/main/default/flows`
- `force-app/main/default/reportTypes`
- `force-app/main/default/reports`

## Notes

- The dependency map is generated from metadata files currently in this repository.
- Use the baseline and architecture pattern docs as architectural references for the Opportunity -> ViabilityStudy__c -> Projeto__c -> Instalacao__c lifecycle.

## Regenerate Documentation

- Run: `bash scripts/generate-project-docs.sh`
