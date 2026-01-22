# Casos – Pós-Vendas (Assistência Técnica)

## Alterações de metadados
- Adicionados Record Types no objeto Case:
  - Retomada (`Retomada`)
  - Operação e Manutenção (`Operacao_e_Manutencao`)
- Campo **Tipo do Caso (Type)** com valores:
  - Concessionária
  - Garantia
  - Gestão de faturas
  - Informação
  - Manutenção
  - Retomada
  - Geral (padrão)
- Campo **Subtipo de caso** como dependente de **Type**, com mapeamentos:
  - Concessionária: Concessionária, Alteração Contratual, Cadastro de Beneficiária
  - Garantia: Garantia de Equipamento, Garantia de Serviço
  - Gestão de faturas: Análise Interna, Análise de Fatura, Reclamação
  - Manutenção: Equipamento, Operação e Manutenção (O&M), Serviço
  - Retomada: Retomada
- Campo **Motivo do Caso (Reason)** com valores para Assistência Técnica:
  - Funcionalidade complexa
  - Manutenção preventiva
  - Novo problema
  - Problema existente
- Campo **Origem do Caso** renomeado para **Forma de contato** e valores para Assistência Técnica:
  - Enerzee
  - Cliente
  - Consultor
- Campo **Oportunidade Pai** renomeado para **Oportunidade de Origem**.

## Automatizações
- Preenchimentos automáticos no Case:
  - **Nome da Oportunidade** a partir da oportunidade de origem.
  - **Conta** vinculada à oportunidade.
  - **Contato** principal (último contato criado da conta).
  - **Nome do Consultor** a partir do consultor relacionado à oportunidade.
- Preenchimento automático de **Assunto** no formato:
  - `TIPO - SUBTIPO - OPORTUNIDADE`

## Arquivos principais
- `force-app/main/default/standardValueSets/CaseType.standardValueSet-meta.xml`
- `force-app/main/default/standardValueSets/CaseReason.standardValueSet-meta.xml`
- `force-app/main/default/standardValueSets/CaseOrigin.standardValueSet-meta.xml`
- `force-app/main/default/objects/Case/fields/Subtipo_de_caso__c.field-meta.xml`
- `force-app/main/default/objects/Case/fields/Origin.field-meta.xml`
- `force-app/main/default/objects/Case/fields/Oportunidade_Pai__c.field-meta.xml`
- `force-app/main/default/objects/Case/recordTypes/*.recordType-meta.xml`
- `force-app/main/default/classes/core/BO/CaseBO.cls`
- `force-app/main/default/classes/core/handlers/CaseTriggerHandler.cls`
