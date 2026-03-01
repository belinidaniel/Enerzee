# Guia de Uso — Claude Code no Projeto Enerzee

Este documento explica como usar o Claude Code de forma eficiente neste projeto, incluindo todos os comandos disponíveis, fluxos de trabalho recomendados e dicas práticas.

---

## O que é o Claude Code

Claude Code é o CLI da Anthropic que roda no seu terminal e tem acesso direto ao código do projeto. Diferente do Codex (que usa agentes separados), o Claude Code:

- **Lê e edita arquivos diretamente** no seu filesystem
- **Executa comandos** via terminal (git, sf, etc.)
- **Mantém contexto do projeto** via `CLAUDE.md` (carregado automaticamente em toda sessão)
- **Tem comandos reutilizáveis** via `.claude/commands/` (slash commands)

---

## Configuração Já Feita

| Arquivo                           | Descrição                                                  |
| --------------------------------- | ---------------------------------------------------------- |
| `CLAUDE.md`                       | Contexto permanente do projeto (carregado automaticamente) |
| `.claude/commands/analyst.md`     | Modo analista de negócio                                   |
| `.claude/commands/architect.md`   | Modo arquiteto técnico                                     |
| `.claude/commands/developer.md`   | Modo desenvolvedor                                         |
| `.claude/commands/jira.md`        | Geração de ticket Jira                                     |
| `.claude/commands/deploy.md`      | Geração de pacote de deploy                                |
| `.claude/commands/impact.md`      | Análise de impacto de mudança                              |
| `.claude/commands/apex-review.md` | Review de código Apex                                      |
| `.claude/commands/flow-review.md` | Review de Flow                                             |

---

## Slash Commands — Referência Rápida

### `/analyst [input]`

Ativa o modo analista. Use quando você tem uma demanda bruta (reunião, e-mail, anotação) e precisa transformar em requisitos estruturados prontos para desenvolvimento.

**Quando usar:**

- Saiu de uma reunião com stakeholders e precisa documentar
- Recebeu um pedido informal por Slack/WhatsApp
- Precisa gerar os critérios de aceite antes de criar o ticket

**Exemplo:**

```
/analyst O cliente quer receber um email quando a instalação for concluída,
avisando sobre o prazo de garantia e pedindo NPS.
```

---

### `/architect [input ou pergunta]`

Ativa o modo arquiteto. Use para decisões técnicas, design de soluções, revisão de arquitetura, ou quando precisa avaliar opções antes de implementar.

**Quando usar:**

- Decidir Flow vs Apex para uma nova automação
- Projetar um novo objeto ou relacionamento
- Avaliar impacto de refactor no modelo de dados existente
- Revisar uma proposta técnica de terceiro

**Exemplo:**

```
/architect Preciso notificar o consultor quando uma Opportunity muda para Closed Won.
Qual é a melhor abordagem considerando que já temos 31 Flows na Opportunity?
```

---

### `/developer [requisito ou tarefa]`

Ativa o modo desenvolvedor. Use para escrever ou revisar código Apex, LWC, classes de teste, ou scripts de automação.

**Quando usar:**

- Implementar uma nova funcionalidade já arquitetada
- Escrever uma classe de teste
- Refatorar código existente seguindo os padrões do projeto
- Implementar uma integração SAP

**Exemplo:**

```
/developer Criar um Queueable para enviar dados de Instalacao__c ao SAP quando
o status mudar para "Concluída". Endpoint via Integrador__mdt.
```

---

### `/jira [descrição da demanda]`

Gera um ticket Jira estruturado e completo, pronto para copiar e colar.

**Quando usar:**

- Antes de criar um ticket no Jira
- Para formalizar uma demanda informal
- Para garantir que critérios de aceite estão bem definidos

**Exemplo:**

```
/jira Adicionar campo de Potência do Sistema no layout do Projeto para o time de engenharia
```

---

### `/deploy [lista de componentes ou "changed"]`

Gera um `package.xml` para deploy manual via SF CLI.

**Quando usar:**

- Antes de fazer deploy de uma feature
- Para garantir que nenhum componente de dependência foi esquecido

**Exemplos:**

```
/deploy changed
```

```
/deploy OpportunityBO, OpportunityTriggerHandler, OpportunityTrigger, OpportunityBOTest
```

---

### `/impact [componente ou mudança]`

Analisa o blast radius de uma mudança no org.

**Quando usar:**

- Antes de deletar/renomear um campo
- Antes de alterar um objeto muito referenciado
- Antes de desativar uma Validation Rule ou Flow

**Exemplo:**

```
/impact Desativar o campo Oportunidade__c no objeto Projeto__c
```

---

### `/apex-review [código ou caminho do arquivo]`

Review completo de uma classe Apex contra os padrões do Enerzee.

**Quando usar:**

- Antes de fazer merge de um PR
- Ao revisar código de terceiros ou consultores
- Após escrever uma nova classe

**Exemplo:**

```
/apex-review force-app/main/default/classes/IntegracaoSAPKit.cls
```

---

### `/flow-review [nome ou descrição do flow]`

Review de um Flow contra os padrões do Enerzee.

**Quando usar:**

- Antes de ativar um Flow novo
- Ao receber um Flow de outro desenvolvedor ou consultor
- Para diagnosticar problemas de performance em Flow existente

**Exemplo:**

```
/flow-review Project_After_Update
```

---

## Fluxos de Trabalho Recomendados

### Fluxo 1: Nova Demanda de Negócio

```
Reunião/Request informal
       ↓
/analyst [input bruto]
       ↓
Requisitos estruturados + critérios de aceite
       ↓
/jira [requisitos]
       ↓
Ticket Jira pronto
       ↓
/architect [requisitos]
       ↓
Decisão técnica documentada
       ↓
/developer [decisão técnica]
       ↓
Código production-ready
       ↓
/apex-review ou /flow-review
       ↓
/deploy changed
```

---

### Fluxo 2: Bug ou Análise de Impacto

```
Report de bug ou mudança proposta
       ↓
/impact [componente afetado]
       ↓
Mapeamento de risco
       ↓
/architect [diagnóstico]
       ↓
Plano de correção
       ↓
/developer [plano]
       ↓
Fix com teste
       ↓
/deploy [componentes corrigidos]
```

---

### Fluxo 3: Review de Código de Terceiro

```
Código recebido (consultor, IA, etc.)
       ↓
/apex-review [código]  ou  /flow-review [flow]
       ↓
Lista de problemas priorizados
       ↓
/developer [correções necessárias]
```

---

## Dicas para Trabalhar Bem com Claude Code

### Seja específico sobre o contexto

Em vez de "revise esse código", diga "revise esse código considerando que é chamado de um Trigger After Update em bulk de 200 registros".

### Use o modelo de dados do CLAUDE.md como âncora

Quando falar sobre objetos, use sempre os nomes API (`Projeto__c`, não "Projeto" ou "Project").

### Para tarefas longas, use o plano

Antes de implementar algo complexo, peça `EnterPlanMode` para validar a abordagem antes de qualquer código ser escrito.

### Para análise de arquivos grandes, seja direto

Em vez de "olhe a pasta classes", peça "leia `force-app/main/default/classes/OpportunityBO.cls` e me diga como está estruturado o método `createSellBuyOrder`".

### Confirme antes de deploys

Sempre gere o package.xml com `/deploy` e faça `--dry-run` antes do deploy real.

### Use comandos encadeados

```
/analyst [input]
→ revise os requisitos
→ /architect [requisitos aprovados]
→ implemente usando /developer
```

---

## Comparação: Claude Code vs Codex

| Aspecto                | Codex                 | Claude Code                              |
| ---------------------- | --------------------- | ---------------------------------------- |
| Acesso a arquivos      | Via tools do agente   | Direto no filesystem                     |
| Execução de comandos   | Via shell do agente   | Terminal local real                      |
| Contexto permanente    | `SKILL.md` por agente | `CLAUDE.md` único carregado sempre       |
| Comandos reutilizáveis | `SKILL.md` por pasta  | `.claude/commands/*.md` (slash commands) |
| Modelo                 | GPT-4o / o3           | Claude Sonnet/Opus                       |
| Edição de código       | Propõe mudanças       | Edita arquivos diretamente               |
| Deploy                 | Manual sempre         | Manual sempre (sem GitHub Actions)       |

**Recomendação**: Use Claude Code como seu par programador no terminal. Os slash commands substituem os skills do Codex com a vantagem de que Claude Code pode ler os arquivos reais do projeto, executar git, e fazer edições diretamente.

---

## Deploy Manual — Referência Rápida

Como não há GitHub Actions, todos os deploys são manuais:

```bash
# Autenticar no org
sf org login web --alias <meu-org>

# Validar sem fazer deploy (dry-run)
sf project deploy start \
  --manifest manifest/package-[feature].xml \
  --target-org <alias> \
  --dry-run \
  --test-level RunLocalTests

# Deploy real
sf project deploy start \
  --manifest manifest/package-[feature].xml \
  --target-org <alias> \
  --test-level RunLocalTests

# Deploy de arquivo único (rápido, dev apenas)
sf project deploy start \
  --source-dir force-app/main/default/classes/MinhaClasse.cls \
  --target-org <alias>

# Verificar status do deploy
sf project deploy report --target-org <alias>

# Rodar testes específicos
sf apex run test \
  --class-names MinhaClasseTest \
  --target-org <alias> \
  --result-format human \
  --wait 10
```

---

## Objetos Principais do Projeto

| API Name            | Label                 | Descrição                         |
| ------------------- | --------------------- | --------------------------------- |
| `Opportunity`       | Oportunidade          | Ciclo comercial — objeto central  |
| `ViabilityStudy__c` | Estudo de Viabilidade | Análise técnica pré-venda         |
| `Projeto__c`        | Projeto               | Execução pós-venda                |
| `Instalacao__c`     | Instalação            | Instalação física do sistema      |
| `Kit_Instalacao__c` | Kit de Instalação     | Produtos/kits da oportunidade     |
| `Faturamento__c`    | Faturamento           | Registro financeiro               |
| `Consultor__c`      | Consultor             | Parceiro/consultor de vendas      |
| `Parceiro__c`       | Parceiro              | Empresa parceira                  |
| `Integradores__c`   | Integrador            | Empresa integradora de instalação |
| `Log__c`            | Log                   | Logs de integração SAP/externa    |

---

## Padrão de Integração SAP (Resumo)

```
[Trigger] → [TriggerHandler] → [BO.metodo()] → [IntegracaoSAP*.sendX()]
                                                        ↓
                                               [Integrador__mdt — endpoint]
                                                        ↓
                                               [HTTP Callout @future/Queueable]
                                                        ↓
                                               [Log__c — resultado]
```

Processos SAP ativos: Cliente, Consultor/Fornecedor, Representante, Integrador, Kit, Pedido de Venda, Pedido de Compra, Contrato.
