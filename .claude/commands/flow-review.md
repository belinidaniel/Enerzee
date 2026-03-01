# Flow Review — Enerzee

Faça uma revisão técnica de um Salesforce Flow contra os padrões do projeto Enerzee.

## Input

$ARGUMENTS

_(Informe o nome do flow, cole o XML, ou descreva o comportamento para revisar)_

## O que avaliar

### 1. Tipo e trigger correto

- [ ] Record-Triggered Flow: Before Save vs After Save escolhido corretamente?
  - Before Save: atualização de campos no mesmo registro (sem DML extra)
  - After Save: criar registros relacionados, enviar emails, chamar subflows
- [ ] Schedule-Triggered ou Platform Event-Triggered: justificado?

### 2. Performance e Governor Limits

- [ ] Loops sem DML ou SOQL interno?
- [ ] Coleções usadas para processar em batch em vez de registro por registro?
- [ ] Número de elementos do flow razoável (complexidade controlada)?
- [ ] Subflows usados para reutilização de lógica?

### 3. Consistência com automações existentes

- [ ] Verifica sobreposição com triggers Apex existentes no mesmo objeto?
  - Objetos com triggers: Account, Opportunity, ViabilityStudy**c, Projeto**c, Instalacao\_\_c, Case, Contact, Lead, Task...
- [ ] Não duplica lógica que já existe em BO classes?
- [ ] Respeita a ordem de execução Salesforce?

### 4. Integridade de dados

- [ ] Validações antes de criar/atualizar registros?
- [ ] Tratamento de erros (Fault paths configurados)?
- [ ] Campos obrigatórios da cadeia Opportunity→ViabilityStudy→Projeto→Instalacao respeitados?

### 5. Manutenibilidade

- [ ] Elementos nomeados de forma descritiva (não "Assignment 1", "Decision 2")?
- [ ] Descrição do Flow e dos elementos principais preenchida?
- [ ] Versão ativa vs versão rascunho controlada?

### 6. Segurança

- [ ] Contexto de execução correto (System vs User)?
- [ ] Dados de usuários externos não expostos?

## Output esperado

```
RESUMO: [nome do flow, tipo, objeto, trigger]
RISCO: [BAIXO / MÉDIO / ALTO]

PROBLEMAS ENCONTRADOS:
  SEVERIDADE | ELEMENTO | PROBLEMA | RECOMENDAÇÃO

BOAS PRÁTICAS OBSERVADAS:
  [lista]

AÇÕES ANTES DE ATIVAR:
  [checklist]
```
