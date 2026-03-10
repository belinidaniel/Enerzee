# Opportunity Product Selector por Regiao

## O que foi implementado

- Quick Action custom em Opportunity: `Selecionar Produtos`.
- Filtro padrão por `Opportunity.RegiaoInstalacao__c` (fórmula derivada de `EstadoInstalacao__c`).
- Busca incremental automática (debounce ~300ms) em `Name`, `ProductCode`, `ExternalId__c` e `Description`.
- Override opcional `Mostrar todas as regiões`.
- Inclusão de `OpportunityLineItem` usando `PricebookEntry` do `Pricebook2Id` da própria Opportunity.
- Retorno por item de inclusão (sucesso/erro).

## Componentes e classes

- LWC Quick Action: `opportunityProductSelectorAction`
- LWC UI: `opportunityProductSelector`
- Apex: `OpportunityProductSelectorController`
- Campo fórmula: `Opportunity.RegiaoInstalacao__c`
- Quick Action metadata: `Opportunity.Selecionar_Produtos_por_Regiao`

## Regras principais

- Se `EstadoInstalacao__c` estiver vazio, a inclusão é bloqueada com mensagem orientativa.
- Se `RegiaoInstalacao__c` não puder ser derivada, o filtro padrão não é aplicado e a inclusão também é bloqueada.
- Sem override, a busca filtra produtos por `Product2.Family = RegiaoInstalacao__c`.

## Limitações conhecidas

- A quantidade é informada por item selecionado; não há edição de preço na UI.
- O comportamento depende de permissões CRUD/FLS do usuário para Opportunity, Product2, PricebookEntry e OpportunityLineItem.
- A ação foi adicionada às flexipages de Opportunity já customizadas no repositório.
