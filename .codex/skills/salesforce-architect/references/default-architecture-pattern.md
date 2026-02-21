# Padrao Arquitetural Recomendado (Projeto Enerzee)

## 1) Modelo de dados recomendado

- `Opportunity (1) -> (N) ViabilityStudy__c`
  - Campo: `ViabilityStudy__c.Opportunity__c`
  - Estrategia: `Lookup` required ou `Master-Detail` se ownership permitir.

- `ViabilityStudy__c (1) -> (N) Projeto__c`
  - Campo: `Projeto__c.Viabilidade__c`
  - Estrategia: `Lookup` required.

- `Opportunity (1) -> (N) Projeto__c`
  - Campo: `Projeto__c.Oportunidade__c`
  - Estrategia: manter para filtro/navegacao direta.

- `Projeto__c (1) -> (N) Instalacao__c`
  - Campo: `Instalacao__c.Projeto__c`
  - Estrategia: `Lookup` required ou `Master-Detail` se cascata desejada.

- `Opportunity (1) -> (N) Instalacao__c` (opcional)
  - Campo: `Instalacao__c.Oportunidade__c`
  - Estrategia: manter somente se houver necessidade de filtro direto sem atraves de Projeto.

## 2) Regras anti-orfao recomendadas

### Projeto coerente com Viabilidade

Validation Rule em `Projeto__c`:

```text
AND(
  NOT(ISBLANK(Viabilidade__c)),
  NOT(ISBLANK(Oportunidade__c)),
  Oportunidade__c <> Viabilidade__r.Opportunity__c
)
```

### Instalacao coerente com Projeto

Validation Rule em `Instalacao__c`:

```text
AND(
  NOT(ISBLANK(Projeto__c)),
  NOT(ISBLANK(Oportunidade__c)),
  Oportunidade__c <> Projeto__r.Oportunidade__c
)
```

### Presenca minima de relacionamentos

- Tornar `ViabilityStudy__c.Opportunity__c` obrigatorio.
- Tornar `Projeto__c.Viabilidade__c` e `Projeto__c.Oportunidade__c` obrigatorios.
- Tornar `Instalacao__c.Projeto__c` obrigatorio.

## 3) Flow recomendado

Before-save Flow em `Projeto__c`:

- Se `Viabilidade__c` estiver vazio e `Oportunidade__c` preenchido:
  - Preencher `Viabilidade__c` com `Opportunity.MainViability__c` (quando existir).
- Se ambos preenchidos:
  - Validar coerencia com `Viabilidade__r.Opportunity__c`.

## 4) Estrategia de Custom Report Type

- Base object: `Opportunity`
- Join chain:
  - `Estudos_de_Viabilidades__r`
  - `ProjetosViabilidade__r`
  - `Instalacoes__r`
- Uso de join:
  - `with or without` para visao completa de funil.
  - `with` para recortes com etapa obrigatoria.

## 5) Colunas minimas de relatorio

- Opportunity: `Name`, `Owner`, `StageName`, `CloseDate`, `MainViability__c`
- Viabilidade: `Name`, `StatusFeasibility__c`, `DateTimeVisit__c`
- Projeto: `Name`, `Status__c`, `DataInicioContrato__c`, `DataTermino__c`
- Instalacao: `Name`, `Status__c`, `DataPrevisaoConclusao__c`, `DataConclusao__c`

## 6) Checklist objetivo

- Nao criar `Projeto__c` sem `Oportunidade__c` e `Viabilidade__c`.
- Nao criar `Instalacao__c` sem `Projeto__c`.
- Bloquear inconsistencias entre lookups paralelos.
- Exibir dados ponta a ponta no report type existente.
- Manter zero duplicacao de campos de Viabilidade em Projeto.
