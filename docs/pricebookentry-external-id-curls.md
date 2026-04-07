# Deploy e testes da feature `PricebookEntry.ExternalId__c`

## Package

Manifesto de deploy:

`Manifest/package-pricebookentry-external-id.xml`

Exemplo de deploy:

```bash
sf project deploy start \
  --manifest Manifest/package-pricebookentry-external-id.xml \
  --target-org <ORG_ALIAS>
```

## Variaveis base

```bash
export SF_HOST="https://seu-dominio.my.salesforce.com"
export SF_TOKEN="seu_token_bearer"
```

Observacoes:

- O endpoint de atualizacao de preco usa `PATCH`.
- O endpoint de desativacao usa `POST`.
- O endpoint de oportunidade usa `PUT`.
- Para `Category__c`, use um valor valido do Global Value Set `TipoKitPromocional` ou envie `null`.

## 1. Desativar lista de `PricebookEntry` por `externalId`

```bash
curl -sS -X POST "$SF_HOST/services/apexrest/PricebookEntryDeactivate" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    { "externalId": "53983SUL-OLD" },
    { "externalId": "54008CO-OLD" }
  ]'
```

Esperado: itens com status `Deactivated`, `AlreadyInactive` ou `NotFound`.

## 2. Atualizar um `PricebookEntry` existente pelo mesmo `externalId`

```bash
curl -sS -X PATCH "$SF_HOST/services/apexrest/ProductUpdateEntry" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "externalId": "53983SUL",
      "name": "610 Wp - JA BIFACIAL",
      "price": 561.008662775,
      "productFamily": "SUL",
      "productCode": "ITM10574SUL",
      "Category__c": null
    }
  ]'
```

Esperado: item com status `Updated`.

## 3. Criar novo `PricebookEntry` para produto existente via `productCode`

Antes deste teste, desative o preco ativo antigo do produto.

```bash
curl -sS -X PATCH "$SF_HOST/services/apexrest/ProductUpdateEntry" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "externalId": "53983SUL-V2",
      "name": "610 Wp - JA BIFACIAL",
      "price": 565.10,
      "productFamily": "SUL",
      "productCode": "ITM10574SUL",
      "Category__c": null
    }
  ]'
```

Esperado: item com status `Created`.

## 4. Criar novo produto quando nao vier `productCode`

```bash
curl -sS -X PATCH "$SF_HOST/services/apexrest/ProductUpdateEntry" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "externalId": "NOVO-PBE-001",
      "name": "Produto sem codigo",
      "price": 99.90,
      "productFamily": "SUL",
      "Category__c": null
    }
  ]'
```

Esperado: item com status `Created`, com `productId` e `pricebookEntryId`.

## 5. Validar conflito quando ja existe outro `PricebookEntry` ativo no produto

Nao desative o preco ativo antes deste teste.

```bash
curl -sS -X PATCH "$SF_HOST/services/apexrest/ProductUpdateEntry" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "externalId": "53983SUL-CONFLICT",
      "name": "610 Wp - JA BIFACIAL",
      "price": 570.00,
      "productFamily": "SUL",
      "productCode": "ITM10574SUL",
      "Category__c": null
    }
  ]'
```

Esperado: item com status `Conflict`.

## 6. Atualizar produtos da oportunidade usando `externalId` do `PricebookEntry`

```bash
curl -sS -X PUT "$SF_HOST/services/apexrest/OpportunityEntry" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "opportunityId": "006U500000XbrlXIAR",
    "Products": [
      {
        "Id": "53983SUL",
        "Name": "610 Wp - JA BIFACIAL",
        "UnitaryValue": 561.008662775,
        "UnitaryValueMaxModules": 0,
        "Quantity": 9,
        "AdditionalFixedCost": 0,
        "FinancialCostWeg": 0,
        "Installation": 0,
        "Direct": 0,
        "Rede": 0,
        "Pontos": 0,
        "Bdi": 0,
        "Description": null
      }
    ]
  }'
```

Esperado: resposta com `opportunityId` e `insertedItems`.

## 7. Teste legado de fallback por produto no `OpportunityEntry`

Se o `Id` enviado ainda for um `productCode` legado, o endpoint tenta localizar o produto e usar o `PricebookEntry` ativo.

```bash
curl -sS -X PUT "$SF_HOST/services/apexrest/OpportunityEntry" \
  -H "Authorization: Bearer $SF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "opportunityId": "006U500000XbrlXIAR",
    "Products": [
      {
        "Id": "ITM10574SUL",
        "Name": "610 Wp - JA BIFACIAL",
        "UnitaryValue": 561.008662775,
        "Quantity": 9,
        "Description": "Fallback por ProductCode"
      }
    ]
  }'
```

Esperado: sucesso somente se existir um `PricebookEntry` ativo para o produto no pricebook da oportunidade.
