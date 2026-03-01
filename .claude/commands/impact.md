# Análise de Impacto — Enerzee

Analise o impacto de uma mudança proposta no org Salesforce Enerzee.

## Input

$ARGUMENTS

_(Pode ser: nome de campo, objeto, classe, flow, integração, ou descrição da mudança)_

## O que fazer

Execute uma análise completa de blast radius considerando:

### 1. Cadeia de dados principal

Verifique se a mudança afeta os objetos:

- `Opportunity`
- `ViabilityStudy__c`
- `Projeto__c`
- `Instalacao__c`

Impactos em campos de fórmula, rollup, cross-object lookups.

### 2. Automações

Identifique:

- **Triggers** que referenciam o componente afetado
- **Flows** que leem ou escrevem no componente (especialmente os 31 Flows de Opportunity)
- **Process Builders** legados (se existirem)
- **Validation Rules** que podem ser ativadas/desativadas

### 3. Integrações

Verifique se o componente é consumido por:

- Integrações SAP (`IntegracaoSAP*.cls`)
- ClickSign (`ClickSign__c`, `ClickSignEnvelope__c`)
- Nivello (`IntegracaoNivello*.cls`)

### 4. UI e Experiência

- **Flexipages** que expõem o componente
- **LWC** que referenciam o objeto/campo
- **Layouts** que contêm o campo
- **Report Types** e **Relatórios** que dependem do componente

### 5. Segurança

- **Permission Sets** que controlam acesso ao componente
- **Profiles** com permissões explícitas
- Impacto em FLS para usuários em campo

### 6. Testes

- Classes de teste que precisarão ser atualizadas
- Risco de regressão nos cenários existentes

## Output esperado

```
RESUMO DO IMPACTO
Risco: [BAIXO / MÉDIO / ALTO / CRÍTICO]
Objetos afetados: X
Flows afetados: X
Classes afetadas: X

DETALHAMENTO
[por categoria acima]

AÇÕES RECOMENDADAS ANTES DO DEPLOY
[checklist]

DEPENDÊNCIAS A VALIDAR
[lista]
```
