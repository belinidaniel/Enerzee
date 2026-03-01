# Merge Deploy — Enerzee

Faz o deploy para a org após o merge de um PR. Identifica os componentes alterados, gera o package.xml, executa os testes e reporta o resultado.

## Input

$ARGUMENTS

_(Formato: `<org-alias> [branch-ou-commit-range]`
Exemplos: `enerzee-prod`, `enerzee-sandbox feature/minha-feature`, `enerzee-prod main~1..main`)_

## O que fazer

### 1. Identificar o escopo do deploy

**Se o input tiver um branch ou range de commits:**
```bash
git diff --name-only <base>..<head>
```

**Se não informado — usar o último merge no branch atual:**
```bash
git diff --name-only HEAD~1..HEAD
```

Liste os arquivos por categoria (Apex, Trigger, LWC, Flow, Object, Field, etc.).

### 2. Gerar o package.xml de deploy

Use o mapeamento de tipos abaixo e gere `manifest/package-deploy-<timestamp>.xml`:

| Pasta / Extensão                                      | MetadataType               |
| ----------------------------------------------------- | -------------------------- |
| `classes/*.cls`                                       | `ApexClass`                |
| `triggers/*.trigger`                                  | `ApexTrigger`              |
| `lwc/*/`                                              | `LightningComponentBundle` |
| `flows/*.flow-meta.xml`                               | `Flow`                     |
| `objects/*/fields/*.field-meta.xml`                   | `CustomField`              |
| `objects/*/*.object-meta.xml`                         | `CustomObject`             |
| `objects/*/validationRules/*.validationRule-meta.xml` | `ValidationRule`           |
| `permissionsets/*.permissionset-meta.xml`             | `PermissionSet`            |
| `profiles/*.profile-meta.xml`                         | `Profile`                  |
| `flexipages/*.flexipage-meta.xml`                     | `FlexiPage`                |
| `customMetadata/*.md`                                 | `CustomMetadata`           |
| `labels/*.labels-meta.xml`                            | `CustomLabels`             |

### 3. Identificar classes de teste

Para cada Apex class alterada, mapear a classe de teste correspondente:
- `FooBO.cls` → procurar `FooBOTest.cls`, `FooBO_Test.cls`, `TestFooBO.cls`
- Incluir no `--tests` do deploy

Se nenhuma classe de teste for encontrada para uma classe alterada, avisar:
> ⚠️ `BarBO.cls` não tem classe de teste mapeada — usando RunLocalTests como fallback

### 4. Executar o deploy

**Com testes específicos (preferido quando há classes de teste mapeadas):**
```bash
sf project deploy start \
  --manifest manifest/package-deploy-<timestamp>.xml \
  --target-org <alias> \
  --test-level RunSpecifiedTests \
  --tests <TestClass1> <TestClass2> \
  --verbose
```

**Fallback — todos os testes locais:**
```bash
sf project deploy start \
  --manifest manifest/package-deploy-<timestamp>.xml \
  --target-org <alias> \
  --test-level RunLocalTests \
  --verbose
```

> ⚠️ **Nunca usar `NoTestRun` em produção.** Apenas em sandboxes de desenvolvimento com aprovação explícita.

### 5. Verificar resultado

Após o deploy, mostrar:
- Status geral: ✅ Succeeded / ❌ Failed
- Componentes deployados: N de N
- Testes executados: N passed, N failed, N% coverage
- Erros (se houver): arquivo + linha + mensagem

Se falhou, sugerir próximos passos:
- Erro de compilação → indicar o arquivo e a linha
- Erro de teste → mostrar o assert que falhou
- Erro de deployment rule → verificar dependências no package.xml

## Output esperado

```
## Merge Deploy Report
Org: <alias>
Timestamp: YYYY-MM-DD HH:mm
Componentes: manifest/package-deploy-<timestamp>.xml

### Escopo do Deploy
- Apex: X classes (Y com teste mapeado, Z sem)
- Triggers: N
- LWC: N
- Flows: N
- Other: N

### Testes executados
RunSpecifiedTests: FooBOTest, BarBOTest, BazBOTest
Coverage: XX% (mínimo obrigatório: 75%)

### Resultado
✅ Deploy concluído com sucesso — N componentes em <X segundos>

ou

❌ Deploy falhou
  - FooBO.cls:42 — Variable does not exist: accountList
  - FooBOTest:88 — Assert.areEqual failed: expected 1, got 0

### Próximos passos (se falhou)
1. Corrigir FooBO.cls linha 42
2. Re-rodar: sf project deploy start --manifest manifest/package-deploy-<timestamp>.xml --target-org <alias>
```
