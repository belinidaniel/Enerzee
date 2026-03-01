# Gerar Pacote de Deploy — Enerzee

Gere um `package.xml` de deploy baseado nos arquivos/componentes informados.

## Input

$ARGUMENTS

_(Pode ser: lista de arquivos, nomes de classes/flows/objetos, descrição de uma feature, ou "changed" para usar o git diff)_

## O que fazer

1. Se o input mencionar "changed" ou "git", analise os arquivos modificados com `git status` e `git diff --name-only HEAD`
2. Para cada componente identificado, determine o `MetadataType` correto do Salesforce
3. Gere um `package.xml` válido para SFDX / SF CLI
4. Liste advertências de dependências (ex: se um Flow for incluído, verificar se os objetos/campos que ele usa também estão no pacote)
5. Sugira o comando SF CLI correspondente

## Mapeamento de tipos comuns

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
| `reportTypes/*.reportType-meta.xml`                   | `ReportType`               |
| `pages/*.page`                                        | `ApexPage`                 |
| `customMetadata/*.md`                                 | `CustomMetadata`           |
| `labels/*.labels-meta.xml`                            | `CustomLabels`             |
| `email/*`                                             | `EmailTemplate`            |

## Output esperado

### package.xml

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- componentes gerados aqui -->
    <version>62.0</version>
</Package>
```

### Comando de deploy

```bash
# Validar (dry-run)
sf project deploy start --manifest manifest/package-[feature-name].xml --target-org <alias> --dry-run

# Deploy real
sf project deploy start --manifest manifest/package-[feature-name].xml --target-org <alias>
```

### Advertências

Liste dependências não incluídas e riscos do deploy.
