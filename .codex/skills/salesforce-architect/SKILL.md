---
name: salesforce-architect
description: Arquitetar especificacoes tecnicas Salesforce para o fluxo Opportunity -> ViabilityStudy__c -> Projeto__c -> Instalacao__c neste projeto, incluindo modelo de dados, integridade anti-orfao, configuracao Admin/Dev, Custom Report Type e relatorio padrao. Usar quando o usuario pedir desenho de relacionamentos, rastreabilidade ponta a ponta, validacoes, reportabilidade multi-objeto ou troubleshooting dessa cadeia em portugues (pt-BR).
---

# Salesforce Architect

Entregar sempre em portugues (pt-BR) com foco em implementacao Admin/Dev.

## Output Contract

- Responder com secoes numeradas e objetivas.
- Iniciar por `Assumptions`.
- Priorizar API names reais deste repositorio.
- Evitar duplicacao de dados entre Viabilidade, Projeto e Instalacao.
- Explicitar risco tecnico e alternativa quando houver bloqueio.

## Workflow

1. Ler `references/project-metadata-baseline.md` antes de propor mudancas.
2. Declarar assumptions tecnicas e lacunas de informacao.
3. Definir modelo de dados e cardinalidade ponta a ponta.
4. Justificar `Lookup` vs `Master-Detail` com impacto em integridade, ownership, sharing, roll-up e exclusao em cascata.
5. Descrever controles anti-orfao (required, validation rules e flows).
6. Especificar configuracao Salesforce em passos executaveis (campos, regras, flows, permissoes, relatorios).
7. Desenhar o Custom Report Type com a cadeia Opportunity -> Viabilidade -> Projeto -> Instalacao.
8. Fechar com checklist de validacao objetivo e criterio de aceite.

## Required Design Rules

- Tratar `Opportunity` como objeto ancora de rastreabilidade.
- Manter consistencia entre `Projeto__c.Oportunidade__c` e `Projeto__c.Viabilidade__r.Opportunity__c`.
- Manter consistencia entre `Instalacao__c.Oportunidade__c` e `Instalacao__c.Projeto__r.Oportunidade__c`.
- Explicar escolha entre `with` e `with or without` no Report Type.
- Sempre propor solucao sem quebrar reportabilidade existente.

## Default Output Sections

1. Assumptions
2. Modelo de Dados e Relacionamentos
3. Configuracao Salesforce (Admin/Dev)
4. Custom Report Type
5. Relatorio Padrao
6. Checklist de Validacao
7. Riscos, Limitacoes e Alternativas

## Reusable References

- Ler `references/project-metadata-baseline.md` para nomes reais de objetos, campos e report type do projeto.
- Ler `references/default-architecture-pattern.md` para formulas de integridade, estrategia de flow e blueprint de relatorio.

## Quality Bar

- Fornecer API names exatos e formulas reproduziveis.
- Evitar recomendacoes genericas sem mapeamento para metadados reais.
- Incluir criterios de teste claros para cada regra anti-orfao.
