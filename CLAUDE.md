# Enerzee — Claude Code Project Context

This file is auto-loaded by Claude Code in every session. It provides stable project context so you don't repeat yourself.

---

## Project Identity

- **Org**: Enerzee Salesforce (Sales Cloud + Service Cloud + FSL)
- **Stack**: Apex, LWC, Aura (legacy), Visualforce (legacy), Flows, SFDX / SF CLI
- **Integrations**: SAP (REST via `@future(callout=true)` → migrating to Queueable), ClickSign, Nivello
- **Deployment**: Manual via `sf project deploy` — no GitHub Actions in place
- **Language**: Code in English. Comments/docs can be PT-BR or EN. User speaks both.

---

## Core Data Model (Opportunity Lifecycle)

```
Lead → Opportunity (1) → (N) ViabilityStudy__c
                Opportunity (1) → (1) MainViability__c (Lookup to ViabilityStudy__c)
                ViabilityStudy__c (1) → (N) Projeto__c
                Projeto__c (1) → (N) Instalacao__c
```

Supporting objects: `Case`, `WorkOrder`, `ServiceAppointment`, `Faturamento__c`, `Kit_Instalacao__c`, `ClickSign__c`, `Feedback__c`, `Consultor__c`, `Parceiro__c`, `Integradores__c`

Key architectural risks (from docs/):

- Most Lookup fields in the chain are `required=false` — integrity depends on automations
- Several Validation Rules in `ViabilityStudy__c`, `Projeto__c`, `Instalacao__c` are **inactive**
- SAP integrations use `@future` (no retry, no bulkification) — at-risk for governor limits

---

## Architecture Patterns (Mandatory)

### Apex

- **Pattern**: `Trigger → TriggerHandler → BO (Business Object)` — never put logic in triggers directly
- Trigger handlers: `OpportunityTriggerHandler`, `ViabilityStudyTriggerHandler`, `ProjetoTriggerHandler`, `InstalacaoTriggerHandler`
- BO classes: `OpportunityBO`, `ViabilityStudyBO`, `ProjetoBO`, `InstalacaoBO`, `CaseBO`, `FaturamentoBO`
- All code must be **bulkified** (`List<SObject>`, Maps for O(1) lookups)
- Use `with sharing` by default; use `WITH SECURITY_ENFORCED` or `Security.stripInaccessible` in SOQL
- **No DML/SOQL inside loops** — ever
- Async: prefer **Queueable** over `@future` for new work (supports chaining + object params)
- Tests: use `Assert.areEqual` (not `System.assert`), never `SeeAllData=true`, mock callouts with `HttpCalloutMock`

### Custom Metadata vs Settings

- Prefer **Custom Metadata Types** over Custom Settings for configuration
- Endpoint configuration: `Integrador__mdt` is the source of truth for SAP endpoints
- **Never hardcode IDs or tokens**

### LWC

- Prefer `lightning-record-edit-form` + LDS over imperative Apex when possible
- No direct DOM manipulation; use LWC directives
- No Aura Events — use CustomEvent + @wire

### Flows

- Record-triggered Flows follow before-save vs after-save correctly
- 31 Flows on Opportunity — always check existing flows before creating new automation

---

## Deployment Workflow (No CI/CD)

Since there are no GitHub Actions, deployments are manual:

```bash
# Deploy specific components
sf project deploy start --source-dir force-app/main/default/classes/MyClass.cls --target-org <alias>

# Deploy from manifest
sf project deploy start --manifest manifest/package.xml --target-org <alias>

# Validate only (dry-run)
sf project deploy start --manifest manifest/package.xml --target-org <alias> --dry-run

# Run tests
sf apex run test --class-names MyClassTest --target-org <alias> --result-format human
```

Use `/deploy` command (`.claude/commands/deploy.md`) to generate a deployment package manifest from changed files.

---

## File Structure

```
force-app/main/default/
  classes/          # Apex classes + test classes
  triggers/         # One trigger per object
  lwc/              # Lightning Web Components
  flows/            # Salesforce Flows (XML)
  objects/          # Object definitions + fields
  permissionsets/   # Permission Sets
  profiles/         # Profiles
  pages/            # Visualforce pages (legacy)
  flexipages/       # Lightning pages
  reportTypes/      # Custom Report Types
  reports/          # Reports
manifest/           # Deployment manifests (package.xml)
docs/               # Architecture docs, Jira drafts, analysis
.claude/commands/   # Claude Code slash commands (this project)
.codex/skills/      # Codex skills (legacy, kept for reference)
```

---

## Naming Conventions

| Type              | Convention         | Example                                  |
| ----------------- | ------------------ | ---------------------------------------- |
| Apex class        | PascalCase         | `OpportunityBO`, `IntegracaoSAPCliente`  |
| Methods           | camelCase          | `sendCustomerRecordToSAP`                |
| Constants         | UPPER_SNAKE_CASE   | `MAX_RETRY_COUNT`                        |
| Triggers          | `ObjectTrigger`    | `OpportunityTrigger`                     |
| LWC               | camelCase          | `opportunityProposalConsole`             |
| Custom Object     | PascalCase + `__c` | `ViabilityStudy__c`, `Projeto__c`        |
| Custom Field      | PascalCase + `__c` | `MainViability__c`                       |
| Relationship name | PascalCase PT-BR   | `Estudos_de_Viabilidades`, `Instalacoes` |

---

## Available Claude Commands

Run these with `/command-name` in Claude Code:

| Command        | What it does                                                                        |
| -------------- | ----------------------------------------------------------------------------------- |
| `/analyst`     | Activate Salesforce Analyst mode — translate raw input into structured requirements |
| `/architect`   | Activate Salesforce Architect mode — design, review, and improve architecture       |
| `/developer`   | Activate Salesforce Developer mode — write and review production-ready Apex/LWC     |
| `/jira`        | Generate a structured Jira ticket from a description or conversation                |
| `/deploy`      | Generate a deployment package (package.xml) from changed/specified files            |
| `/impact`      | Analyze the blast radius of a change across the data model and automations          |
| `/apex-review` | Deep review of an Apex class against Enerzee standards                              |
| `/flow-review` | Review a Flow for correctness, performance, and best practices                      |

---

## Key Documentation

- `docs/project-dependencies-full.md` — full metadata inventory (409 objects, 356 classes, 141 flows)
- `docs/sap-integracoes-levantamento-arquitetura.md` — SAP integration AS-IS + To-Be design
- `.codex/skills/salesforce-architect-Enerzee/references/project-metadata-baseline.md` — Opportunity chain data model baseline
- `.codex/skills/salesforce-architect-Enerzee/references/default-architecture-pattern.md` — recommended data model patterns
- `docs/apex-coverage-snapshot.md` — latest Apex test coverage snapshot

---

## Key Constraints

- No GitHub Actions — deployment is always manual via SF CLI
- SAP token must come from `Integrador__mdt` — never from hardcoded strings
- All critical Lookup fields in the Opportunity chain are currently `required=false` — do not assume data integrity without validation rules
- When touching `OpportunityBO` or `OpportunityTriggerHandler`, verify all 31 Opportunity Flows before proceeding
