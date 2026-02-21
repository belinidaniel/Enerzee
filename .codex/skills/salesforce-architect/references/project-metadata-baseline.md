# Baseline de Metadados do Projeto

## Objetos alvo

- `Opportunity`
- `ViabilityStudy__c`
- `Projeto__c`
- `Instalacao__c`

## Relacionamentos encontrados (estado atual)

- `ViabilityStudy__c.Opportunity__c`
  - Tipo: `Lookup`
  - Required: `false`
  - RelationshipName: `Estudos_de_Viabilidades`
  - Arquivo: `force-app/main/default/objects/ViabilityStudy__c/fields/Opportunity__c.field-meta.xml`

- `Projeto__c.Viabilidade__c`
  - Tipo: `Lookup`
  - Required: `false`
  - RelationshipName: `ProjetosViabilidade`
  - Arquivo: `force-app/main/default/objects/Projeto__c/fields/Viabilidade__c.field-meta.xml`

- `Projeto__c.Oportunidade__c`
  - Tipo: `Lookup`
  - Required: `false`
  - RelationshipName: `Projetos`
  - Arquivo: `force-app/main/default/objects/Projeto__c/fields/Oportunidade__c.field-meta.xml`

- `Instalacao__c.Projeto__c`
  - Tipo: `Lookup`
  - Required: `false`
  - RelationshipName: `Instalacoes`
  - Arquivo: `force-app/main/default/objects/Instalacao__c/fields/Projeto__c.field-meta.xml`

- `Instalacao__c.Oportunidade__c`
  - Tipo: `Lookup`
  - Required: `false`
  - RelationshipName: `InstalacoesOportunidade`
  - Arquivo: `force-app/main/default/objects/Instalacao__c/fields/Oportunidade__c.field-meta.xml`

## Report Type existente

- API name: `Oportunidades_com_Viabilidade_Projeto_Instalacao`
- Arquivo: `force-app/main/default/reportTypes/Oportunidades_com_Viabilidade_Projeto_Instalacao.reportType-meta.xml`
- Cadeia atual:
  - `Opportunity`
  - `Opportunity.Estudos_de_Viabilidades__r` (outer join)
  - `Opportunity.Estudos_de_Viabilidades__r.ProjetosViabilidade__r` (outer join)
  - `Opportunity.Estudos_de_Viabilidades__r.ProjetosViabilidade__r.Instalacoes__r` (outer join)

## Campo de ancora de viabilidade em Opportunity

- Campo observado no report type: `Opportunity.MainViability__c`
- Uso esperado: apontar para a viabilidade principal da oportunidade.

## Riscos arquiteturais do estado atual

- Lookups criticos com `required=false` permitem registros orfaos.
- Cadeia depende de consistencia entre lookups paralelos (`Viabilidade` e `Oportunidade`) sem garantia nativa.
- Reportabilidade ponta a ponta pode perder linhas em caso de relacionamentos inconsistentes.
