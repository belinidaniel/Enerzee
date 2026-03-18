# Caderno de Testes — Integrações SAP

**Branch:** `feature/SAL-387` (ou `feature/SAL-349-sap-hml-integration`)
**Ambiente QA:** `enerzee-UAT` (jean.carlos@enerzee.com.br.qa)
**SAP HML:** `https://sr89msh3blpz-bbk3vwramwx6.s1p-zona-01-4fd9831d6a58.saas.wevy.cloud/`
**Última atualização:** 2026-03-17

---

## Resumo das Integrações

| Integração    | Classe Apex                  | Endpoint SAP                             | Trigger via                  |
| ------------- | ---------------------------- | ---------------------------------------- | ---------------------------- |
| Cliente       | `IntegracaoSAPCliente`       | `ClienteSAP` → `/`                       | Account (insert/update)      |
| Fornecedor    | `IntegracaoSAPFornecedor`    | `FornecedorSAP` → `/`                    | Consultor (RT Franqueado)    |
| Representante | `IntegracaoSAPRepresentante` | `RepresentanteSAP` → `/`                 | Consultor (RT Consultor)     |
| Kit           | `IntegracaoSAPKit`           | `KitSAP` → `/Kits/Kit`                   | OpportunityLineItem (update) |
| Contrato      | `IntegracaoSAPContrato`      | `ContratoSAP` → `/`                      | Opportunity (stage)          |
| Pedido Compra | `IntegracaoSAPPedidoCompra`  | `PedidoCompraVendaSAP` → `/pedidocompra` | Opportunity (stage)          |
| Pedido Venda  | `IntegracaoSAPPedidoVenda`   | `PedidoCompraVendaSAP` → `/pedidovenda`  | Opportunity (stage)          |

**Nota de ambiente:** Em sandbox, todas as classes usam automaticamente o sufixo `_QA` nos metadata (`ClienteSAP_QA`, `TokenSAP_QA`, etc.) via `Utils.getSAPMetadataName()`.

---

## Pré-condições Gerais

- [ ] Custom Metadata `TokenSAP_QA.LastToken__c` preenchido com token válido do SAP HML
- [ ] Todos os metadata `_QA` deployados no sandbox (`ClienteSAP_QA`, `ContratoSAP_QA`, etc.)
- [ ] Acesso ao Swagger HML: `https://sr89msh3blpz-bbk3vwramwx6.s1p-zona-01-4fd9831d6a58.saas.wevy.cloud/swagger/index.html`
- [ ] Consultar logs em: Setup → Apex Jobs + objeto `Log__c`

---

## 1. Integração: Cliente (Account → SAP BusinessPartner)

**Classe:** `IntegracaoSAPCliente`
**Ticket relacionado:** SAL-349

### CT-CLI-01 — Criar cliente PF (CPF)

**Pré-condição:** Account com `CPF__c` preenchido, sem `CNPJ__c`

| Campo             | Valor               |
| ----------------- | ------------------- |
| Name              | `QA Cliente PF 001` |
| CPF\_\_c          | `347.375.188-08`    |
| Email\_\_c        | `qapf@enerzee.com`  |
| Phone             | `(11) 99999-0001`   |
| BillingStreet     | `Rua Teste, 100`    |
| BillingCity       | `São Paulo`         |
| BillingState      | `São Paulo`         |
| BillingPostalCode | `01310-100`         |
| BillingCountry    | `Brasil`            |

**Ação:** Salvar Account no sandbox
**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true`
- [ ] `StatusBodyIntegracaoSAP__c` contém código 200 ou 201
- [ ] `BPFiscalTaxIDCollection[0].TaxID0` = CPF (campo correto para PF)
- [ ] SAP recebe `CardType = "cCustomer"`

---

### CT-CLI-02 — Criar cliente PJ (CNPJ)

**Pré-condição:** Account com `CNPJ__c` preenchido, sem `CPF__c`

| Campo        | Valor                |
| ------------ | -------------------- |
| Name         | `QA Cliente PJ 001`  |
| CNPJ\_\_c    | `12.345.678/0001-99` |
| Email\_\_c   | `qapj@enerzee.com`   |
| BillingState | `SP`                 |

**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true`
- [ ] `BPFiscalTaxIDCollection[0].TaxID4` = CNPJ (campo correto para PJ)

---

### CT-CLI-03 — Atualizar cliente existente

**Pré-condição:** Account já integrado no CT-CLI-01
**Ação:** Alterar `Phone` e salvar
**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true` (upsert no SAP)

---

### CT-CLI-04 — Cliente sem endereço

**Pré-condição:** Account sem `BillingAddress` e sem `ShippingAddress`
**Resultado esperado:**

- [ ] Integração não lança exceção
- [ ] `BPAddresses = []` na requisição (endereços não enviados)

---

## 2. Integração: Fornecedor (Consultor RT Franqueado → SAP Supplier)

**Classe:** `IntegracaoSAPFornecedor`
**Ticket relacionado:** SAL-314

### CT-FOR-01 — Fornecedor com todos os dados bancários

| Campo               | Valor                 |
| ------------------- | --------------------- |
| Name                | `QA Fornecedor 001`   |
| SeCPFouCNPJ\_\_c    | `98.765.432/0001-01`  |
| Conta\_\_c          | `12345-6`             |
| Agencia\_\_c        | `0001`                |
| Banco\_\_c          | `001`                 |
| RuaCobranca\_\_c    | `Av. Industrial, 500` |
| CidadeCobranca\_\_c | `Campinas`            |
| PaisCobranca\_\_c   | `Brasil`              |

**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true`
- [ ] `DefaultAccount = "12345-6"`, `DefaultBranch = "0001"`, `DefaultBankCode = "001"` enviados
- [ ] `CardType = "cSupplier"`

---

### CT-FOR-02 — Fornecedor com dados bancários parciais (fix SAL-314)

**Cenário:** Apenas `Conta__c` preenchida, `Agencia__c` e `Banco__c` nulos

| Campo        | Valor     |
| ------------ | --------- |
| Conta\_\_c   | `99999-0` |
| Agencia\_\_c | _(vazio)_ |
| Banco\_\_c   | _(vazio)_ |

**Resultado esperado (antes do fix: falhava silenciosamente):**

- [ ] `SucessoIntegracaoSAP__c = true`
- [ ] `DefaultAccount = "99999-0"` enviado
- [ ] `DefaultBranch` e `DefaultBankCode` não enviados (null)

---

### CT-FOR-03 — Fornecedor sem dados bancários

| Campo        | Valor     |
| ------------ | --------- |
| Conta\_\_c   | _(vazio)_ |
| Agencia\_\_c | _(vazio)_ |
| Banco\_\_c   | _(vazio)_ |

**Resultado esperado:**

- [ ] Integração não lança exceção
- [ ] Campos bancários ausentes no JSON (nenhum enviado)

---

### CT-FOR-04 — Fornecedor PF (CPF)

**Pré-condição:** `CPF__c` preenchido, `CNPJ__c` nulo
**Resultado esperado:**

- [ ] `BPFiscalTaxIDCollection[0].TaxID0` = CPF

---

## 3. Integração: Representante (Consultor RT Consultor → SAP SalesPerson)

**Classe:** `IntegracaoSAPRepresentante`

### CT-REP-01 — Criar representante ativo

| Campo            | Valor                  |
| ---------------- | ---------------------- |
| Name             | `QA Representante 001` |
| SeCPFOuCNPJ\_\_c | `111.222.333-44`       |
| Ativo\_\_c       | `true`                 |
| Comissao\_\_c    | `5.0`                  |
| Email\_\_c       | `rep@enerzee.com`      |
| Telefone\_\_c    | `(11) 3333-0001`       |
| Celular\_\_c     | `(11) 99888-0001`      |

**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true`
- [ ] `Active = "tYES"` no payload
- [ ] `U_Alfa_IdIntegracao = CPF/CNPJ`

---

### CT-REP-02 — Representante inativo

| Campo      | Valor   |
| ---------- | ------- |
| Ativo\_\_c | `false` |

**Resultado esperado:**

- [ ] `Active = "tNO"` no payload

---

### CT-REP-03 — Consultor = Representante + Fornecedor (dupla integração)

**Observação:** `ConsultorBO.sendFornecedorRepresentanteRecordToSAP` dispara AMBAS as integrações para o RT Consultor.
**Pré-condição:** Consultor com RT "Consultor" (não Franqueado)
**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true` (via Representante)
- [ ] Também criado como Fornecedor no SAP (verificar no SAP HML)

---

## 4. Integração: Kit (OpportunityLineItem → SAP Item)

**Classe:** `IntegracaoSAPKit`
**Trigger:** Atualização de `OpportunityLineItem.Kit_Instalacao__c`

### CT-KIT-01 — Vincular kit a item de oportunidade

**Pré-condição:** Oportunidade com OpportunityLineItem existente
**Ação:** Setar `Kit_Instalacao__c` no OpportunityLineItem
**Resultado esperado:**

- [ ] Integração disparada via trigger
- [ ] `SucessoIntegracaoSAP__c = true` no Kit

---

## 5. Integração: Contrato (Opportunity → SAP Order/Contract)

**Classe:** `IntegracaoSAPContrato`
**Ticket relacionado:** SAL-369

### CT-CTR-01 — Enviar contrato com kits (sucesso)

**Pré-condição:** Opportunity com pelo menos 1 `Kit_Instalacao__c` vinculado

| Campo                     | Valor                  |
| ------------------------- | ---------------------- |
| Classificacao\_\_c        | `Contratos de Locação` |
| NumeroContrato\_\_c       | `9001`                 |
| NumeroOrigemContrato\_\_c | `ORI-QA-001`           |
| CondicoesPagamento\_\_c   | `Recursos Próprios`    |
| IdVirtualOffice\_\_c      | `VO-QA-001`            |
| DataEntrega\_\_c          | D+30                   |

**Kit vinculado:**

| Campo                     | Valor        |
| ------------------------- | ------------ |
| UnidadeMedidaLocacao\_\_c | `Unidade`    |
| TipoMedicao\_\_c          | `Valor`      |
| TipoFaturamento\_\_c      | `Recorrente` |
| Recorrencia\_\_c          | `Mensal`     |
| VencimentoBase\_\_c       | D+1          |

**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = true`
- [ ] `documentLines[0].U_UnitMeasureHired = "UN"`
- [ ] `documentLines[0].U_BillingType = 3` (Recorrente)
- [ ] `documentLines[0].U_RecurrenceType = 2` (Mensal)

---

### CT-CTR-02 — Todas as classificações (U_Classification)

Testar cada classificação e verificar o mapeamento:

| Classificacao\_\_c                  | U_Classification esperado |
| ----------------------------------- | ------------------------- |
| Contratos de Locação                | 1                         |
| Contratos de Serviços               | 2                         |
| Contratos de Licenciamento          | 3                         |
| Compras de equipamentos e materiais | 4                         |
| Arrendamento de área rural          | 5                         |
| Prestação de Serviços (v)           | 6                         |
| Venda de equipamentos e materiais   | 7                         |

---

### CT-CTR-03 — Oportunidade sem kits

**Resultado esperado:**

- [ ] Integração não dispara callout (kits vazios = sem request)
- [ ] Nenhum erro lançado

---

## 6. Integração: Pedido de Compra (Opportunity → SAP PurchaseOrder)

**Classe:** `IntegracaoSAPPedidoCompra`
**Ticket relacionado:** SAL-72

### CT-PCO-01 — Pedido de compra com CondicoesPagamento numérico

| Campo                   | Valor                   |
| ----------------------- | ----------------------- |
| CondicoesPagamento\_\_c | `30` _(valor numérico)_ |

**Resultado esperado:**

- [ ] `paymentGroupCode = 30` (Integer) no payload SAP
- [ ] `SucessoIntegracaoSAP__c = true`

---

### CT-PCO-02 — CondicoesPagamento com valor textual (fix SAL-72)

| Campo                   | Valor               |
| ----------------------- | ------------------- |
| CondicoesPagamento\_\_c | `Recursos Próprios` |

**Resultado esperado (antes do fix: causava NumberFormatException):**

- [ ] `paymentGroupCode = null` no payload (sem lançar exceção)
- [ ] `SucessoIntegracaoSAP__c = true`

---

### CT-PCO-03 — CondicoesPagamento vazio/nulo

| Campo                   | Valor     |
| ----------------------- | --------- |
| CondicoesPagamento\_\_c | _(vazio)_ |

**Resultado esperado:**

- [ ] `paymentGroupCode = null`
- [ ] Sem erro

---

## 7. Integração: Pedido de Venda (Opportunity → SAP Order)

**Classe:** `IntegracaoSAPPedidoVenda`
**Ticket relacionado:** SAL-72

### CT-PVE-01 — Pedido de venda com FormaPagamento\_\_c (fix SAL-72)

| Campo                   | Valor               |
| ----------------------- | ------------------- |
| FormaPagamento\_\_c     | `R001`              |
| CondicoesPagamento\_\_c | `Recursos Próprios` |

**Resultado esperado:**

- [ ] `paymentMethod = "R001"` no payload SAP
- [ ] `paymentGroupCode = null` (CondicoesPagamento textual → null)
- [ ] `SucessoIntegracaoSAP__c = true`

---

### CT-PVE-02 — Pedido de venda sem FormaPagamento\_\_c

| Campo               | Valor     |
| ------------------- | --------- |
| FormaPagamento\_\_c | _(vazio)_ |

**Resultado esperado:**

- [ ] `paymentMethod = null` no payload
- [ ] Sem erro

---

### CT-PVE-03 — NumeroContrato\_\_c nulo (U_ContractId = 0)

| Campo               | Valor     |
| ------------------- | --------- |
| NumeroContrato\_\_c | _(vazio)_ |

**Resultado esperado:**

- [ ] `U_ContractId = 0` (não lança NullPointerException)
- [ ] `SucessoIntegracaoSAP__c = true`

---

### CT-PVE-04 — Todas as formas de pagamento disponíveis

| FormaPagamento\_\_c | paymentMethod esperado |
| ------------------- | ---------------------- |
| `REC CARTAO`        | `REC CARTAO`           |
| `REC FINANCIAMEN`   | `REC FINANCIAMEN`      |
| `R001`              | `R001`                 |
| `R0002`             | `R0002`                |
| `Negociação`        | `Negociação`           |

---

## 8. Cenários de Erro — Transversais

### CT-ERR-01 — SAP retorna erro 400

**Pré-condição:** Payload inválido (ex.: CardCode ausente)
**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = false`
- [ ] `StatusBodyIntegracaoSAP__c` contém mensagem de erro do SAP

---

### CT-ERR-02 — SAP indisponível (timeout/connection error)

**Resultado esperado:**

- [ ] `SucessoIntegracaoSAP__c = false`
- [ ] `StatusBodyIntegracaoSAP__c` contém stack trace do erro
- [ ] Log criado no objeto `Log__c`

---

### CT-ERR-03 — Token SAP expirado

**Pré-condição:** `TokenSAP_QA.LastToken__c` com token inválido
**Resultado esperado:**

- [ ] SAP retorna 401
- [ ] `SucessoIntegracaoSAP__c = false`

---

## 9. Verificação de Ambiente QA (SAL-349)

### CT-ENV-01 — Confirmar roteamento para HML em sandbox

**Ação:** Executar qualquer integração no sandbox `enerzee-UAT`
**Resultado esperado:**

- [ ] Request vai para `sr89msh3blpz-bbk3vwramwx6.s1p-zona-01-4fd9831d6a58.saas.wevy.cloud`
- [ ] Request NÃO vai para URL de produção
- [ ] Log contém URL correta

**Como verificar:** Checar `Log__c` → `Endpoint__c` (ou campo equivalente) pós-integração.

---

### CT-ENV-02 — Confirmar que produção não usa `_QA`

**Pré-condição:** Deploy em PRD
**Resultado esperado:**

- [ ] Classe usa `ClienteSAP` (sem sufixo)
- [ ] Endpoint apontado: URL de produção do SAP

---

## 10. Checklist de Saída (Definition of Done)

- [ ] CT-CLI-01 a CT-CLI-04: Todos ✅
- [ ] CT-FOR-01 a CT-FOR-04: Todos ✅ (SAL-314 validado)
- [ ] CT-REP-01 a CT-REP-03: Todos ✅
- [ ] CT-KIT-01: ✅
- [ ] CT-CTR-01 a CT-CTR-03: Todos ✅ (SAL-369 validado)
- [ ] CT-PCO-01 a CT-PCO-03: Todos ✅ (SAL-72 validado)
- [ ] CT-PVE-01 a CT-PVE-04: Todos ✅ (SAL-72 validado)
- [ ] CT-ERR-01 a CT-ERR-03: Todos ✅
- [ ] CT-ENV-01 e CT-ENV-02: Confirmados ✅
- [ ] `TokenSAP_QA.LastToken__c` configurado manualmente no org ✅
- [ ] Automated tests: `IntegracaoSAPCoverageTest` 20/20 Pass ✅

---

## Testes Automatizados (referência rápida)

```bash
# Rodar todos os testes de cobertura SAP
sf apex run test --class-names IntegracaoSAPCoverageTest --target-org enerzee-UAT --result-format human --wait 5

# Rodar os testes antigos (Cliente, Representante, Kit, Contrato, Pedidos)
sf apex run test --class-names IntegracaoSAPTest --target-org enerzee-UAT --result-format human --wait 5
```

**Status atual dos testes automatizados:**

| Classe de Teste             | Total      | Pass | Status    |
| --------------------------- | ---------- | ---- | --------- |
| `IntegracaoSAPCoverageTest` | 20         | 20   | ✅ 100%   |
| `IntegracaoSAPTest`         | _(legado)_ | —    | Verificar |
