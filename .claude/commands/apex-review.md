# Apex Code Review — Enerzee

Faça uma revisão técnica completa de código Apex contra os padrões do projeto Enerzee.

## Input

$ARGUMENTS

_(Cole o código Apex ou informe o caminho do arquivo)_

## Checklist de revisão

### 1. Estrutura e Padrão

- [ ] Segue o padrão `Trigger → TriggerHandler → BO`?
- [ ] Lógica de negócio está no BO, não no TriggerHandler ou no Trigger?
- [ ] A classe tem responsabilidade única (SRP)?
- [ ] `with sharing` declarado? Justificado se `without sharing`?

### 2. Bulkificação

- [ ] Métodos aceitam `List<SObject>` em vez de registro único?
- [ ] Nenhum SOQL ou DML dentro de loop?
- [ ] Maps usados para O(1) lookup em vez de consultas aninhadas?
- [ ] Heap e CPU considerados para volumes de 200+ registros?

### 3. Segurança

- [ ] `WITH SECURITY_ENFORCED` ou `Security.stripInaccessible()` nas queries?
- [ ] FLS verificado antes de DML (`isCreatable`, `isUpdateable`, `isDeletable`)?
- [ ] Nenhum ID hardcoded?
- [ ] Nenhum token ou credential em código?

### 4. Qualidade do Código

- [ ] Sem magic numbers — constantes ou Custom Labels?
- [ ] Exception handling adequado (sem `catch` vazio)?
- [ ] Logging em `Log__c` para erros de integração?
- [ ] Comentários onde a lógica não é auto-explicativa?
- [ ] Naming conventions: PascalCase (classe), camelCase (método/variável), UPPER_SNAKE_CASE (constante)?

### 5. Testes (se classe de teste)

- [ ] `SeeAllData=true` ausente?
- [ ] `Assert.areEqual` / `Assert.isTrue` em vez de `System.assert`?
- [ ] Teste de bulk (200 registros)?
- [ ] Callouts mockados com `HttpCalloutMock`?
- [ ] Cobertura de path negativo e exceções?

### 6. Integrações SAP (se aplicável)

- [ ] Endpoint via `Integrador__mdt` (não hardcoded)?
- [ ] Token via Named Credential / `Integrador__mdt`?
- [ ] Queueable em vez de `@future` para trabalho novo?
- [ ] Logging com `RelatedId` em `Log__c`?
- [ ] Mecanismo de retry ou idempotência?

## Output esperado

Para cada problema encontrado:

```
SEVERIDADE: [BLOCKER / MAJOR / MINOR / SUGGESTION]
LINHA: X
PROBLEMA: descrição clara
CORREÇÃO: código ou instrução corretiva
```

No final, um **Score de Qualidade** (0-10) com justificativa e lista priorizada de correções obrigatórias antes do deploy.
