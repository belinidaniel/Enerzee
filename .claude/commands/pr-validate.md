# PR Validation — Enerzee

Valida um Pull Request antes do merge: analisa os arquivos alterados, revisa qualidade Apex, gera o package.xml e roda um dry-run na org alvo.

## Input

$ARGUMENTS

_(Pode ser: alias da org alvo, nome do branch, ou vazio para usar o branch atual vs `main`)_

## O que fazer

### 1. Identificar arquivos alterados

```bash
git diff --name-only main...HEAD
```

Liste os arquivos por categoria:
- Apex classes (`.cls`)
- Triggers (`.trigger`)
- LWC
- Flows
- Objects / Fields
- Other metadata

### 2. Apex Code Review automático

Para cada `.cls` e `.trigger` alterado, verifique:

**Segurança (BLOCKER se falhar):**
- [ ] `with sharing` declarado na classe
- [ ] `WITH SECURITY_ENFORCED` ou `Security.stripInaccessible()` em todas as queries
- [ ] Nenhum ID hardcoded
- [ ] Nenhum token ou URL hardcoded — usar `Integrador__mdt`

**Bulkificação (BLOCKER se falhar):**
- [ ] Nenhum SOQL dentro de loop (`for`, `while`)
- [ ] Nenhum DML dentro de loop
- [ ] Maps usados para lookups O(1)

**Qualidade (MAJOR se falhar):**
- [ ] `catch` nunca vazio — sempre loga em `Log__c` ou `Utils.createLog`
- [ ] try-finally ao redor de DML quando trigger está desabilitado (`disableTrigger / enableTrigger`)
- [ ] Métodos aceitam `List<SObject>`, não registro único

**Estrutura (MINOR):**
- [ ] Segue padrão `Trigger → TriggerHandler → BO`
- [ ] Lógica de negócio não está no TriggerHandler ou Trigger diretamente

### 3. Identificar classes de teste relacionadas

Para cada `FooBar.cls` alterado, procure `FooBarTest.cls` ou `FooBar_Test.cls`:
```bash
git diff --name-only main...HEAD | grep -v Test | sed 's/.cls//'
```

Liste quais classes alteradas **têm** teste e quais **não têm**.

### 4. Gerar package.xml

Use o mapeamento de tipos do `/deploy` e gere o `manifest/package-pr-validate.xml` com todos os componentes alterados.

### 5. Validar na org (dry-run)

Execute o comando de validação com os testes relevantes:

```bash
# Dry-run com testes específicos (preferido)
sf project deploy start \
  --manifest manifest/package-pr-validate.xml \
  --target-org <alias> \
  --dry-run \
  --test-level RunSpecifiedTests \
  --tests <TestClass1> <TestClass2>

# Alternativa: todos os testes locais
sf project deploy start \
  --manifest manifest/package-pr-validate.xml \
  --target-org <alias> \
  --dry-run \
  --test-level RunLocalTests
```

### 6. Checar impacto nos Flows do objeto afetado

Se Apex alterado toca `Opportunity`, avisar:
> ⚠️ Há 31 Flows na Opportunity. Confirme que as mudanças não conflitam com automações existentes.

Para outros objetos, listar Flows conhecidos potencialmente impactados.

## Output esperado

```
## PR Validation Report
Branch: feature/xxx → main
Org: <alias>

### Arquivos alterados (N total)
- Apex: X classes, Y triggers
- LWC: Z components
- Flows: W flows
- Other: ...

### Apex Review
[BLOCKER] FooBO.cls linha 42 — SOQL dentro de loop
[MAJOR]   BarBO.cls linha 18 — catch vazio sem log
[OK]      BazBO.cls — sem problemas

### Cobertura de Testes
✅ FooBO.cls → FooBOTest.cls (encontrado)
❌ BarBO.cls → BarBOTest.cls (NÃO ENCONTRADO — risco de deploy)

### Dry-run Result
✅ Validação passou / ❌ Falhou — [erro]

### Impacto em Flows
⚠️ Opportunity alterada — revisar 31 Flows antes do merge

### Conclusão
🔴 NÃO aprovado para merge — N blockers encontrados
🟡 Aprovado com ressalvas — revisar MAJORs antes do merge
🟢 Aprovado — sem blockers
```
