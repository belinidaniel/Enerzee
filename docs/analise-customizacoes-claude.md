# Análise das Customizações do Claude Code — Projeto Enerzee

> Inventário completo de tudo que está customizado para o Claude neste projeto, com avaliação do que **faz sentido**, do que **não faz sentido**, e do que precisa de **ação urgente**.
>
> Gerado em: 2026-06-06

---

## TL;DR — O que você precisa saber agora

| # | Achado | Severidade | Ação |
|---|--------|-----------|------|
| 1 | **API Key do Clockify em texto puro, commitada no git** (`.claude/commands/clockify.md`) | 🔴 Crítico | Revogar key + remover do arquivo + limpar histórico |
| 2 | **Duplicação total**: `.codex/skills/` (3 skills) replica `.claude/commands/` (analyst/architect/developer) | 🟡 Médio | Decidir: manter Codex ou arquivar |
| 3 | `settings.local.json` com 36 regras `allow` acumuladas, várias ultra-específicas e obsoletas | 🟢 Baixo | Limpar regras one-off |
| 4 | CLAUDE.md tem **contradição interna**: diz "No GitHub Actions" mas também documenta 2 workflows | 🟡 Médio | Corrigir a seção "Key Constraints" |
| 5 | Nenhum **hook** e nenhuma regra `deny`/`ask` configurada | 🟢 Oportunidade | Adicionar guard-rails (ex: bloquear deploy em prod) |

---

## 1. Inventário completo do que está customizado

### 1.1 `CLAUDE.md` (raiz do projeto) — ✅ FAZ SENTIDO
**9.191 bytes, commitado.** Auto-carregado em toda sessão.

Cobre: identidade do projeto, data model da cadeia Opportunity, padrões Apex obrigatórios (`Trigger → TriggerHandler → BO`), CMT vs Settings, LWC, Flows, workflow de deploy, file structure, naming conventions, lista de comandos, docs-chave e a base de conhecimento Obsidian.

**Avaliação**: excelente. É o ativo mais valioso da configuração. Bem estruturado, denso de contexto real, evita repetição. **Único problema**: ver achado #4 (contradição GitHub Actions).

---

### 1.2 `.claude/commands/` — 12 slash commands (commitados)

| Comando | Linhas | Avaliação | Comentário |
|---------|-------:|-----------|-----------|
| `analyst.md` | 45 | ✅ Faz sentido | Modo Business Analyst. Output estruturado (Given/When/Then). |
| `architect.md` | 165 | ✅ Faz sentido | Tem "Passo 0 — Leitura e descoberta" obrigatório antes de propor. Ótimo guard-rail anti-alucinação. |
| `developer.md` | 83 | ✅ Faz sentido | Padrões Apex bem definidos (BO/DAO/Utils/Helper). |
| `refactor.md` | 206 | ✅ Faz sentido | O mais elaborado. "Regra de ouro: nunca gere código que já existe". Protocolo em fases. |
| `apex-review.md` | 69 | ✅ Faz sentido | Checklist de review robusto (estrutura, bulkificação, segurança). |
| `flow-review.md` | 65 | ✅ Faz sentido | Before/After Save, governor limits, subflows. |
| `impact.md` | 78 | ✅ Faz sentido | Blast-radius na cadeia de dados. Útil dado o risco de Lookups `required=false`. |
| `jira.md` | 65 | ✅ Faz sentido | Template de ticket PT-BR pronto p/ colar. |
| `deploy.md` | 63 | ⚠️ Parcial | Gera `package.xml`. Bom — mas ver redundância com pr-validate/merge-deploy. |
| `pr-validate.md` | 124 | ⚠️ Parcial | Sobrepõe `deploy.md` + `apex-review.md`. |
| `merge-deploy.md` | 123 | ⚠️ Parcial | Sobrepõe `deploy.md`. Faz deploy REAL — perigoso sem guard-rail (ver #5). |
| `clockify.md` | 47 | 🔴 PROBLEMA | **Contém API key em texto puro.** Ver achado #1. |

**Resumo dos commands**: o conjunto analyst/architect/developer/refactor/review/impact/jira é **coerente e bem-feito** — reflete os padrões reais do projeto. O trio deploy/pr-validate/merge-deploy tem **sobreposição funcional** que vale consolidar. O clockify é um risco de segurança.

---

### 1.3 `.codex/skills/` — 3 skills (commitadas, congeladas em 01/Mar) — ❌ NÃO FAZ MAIS SENTIDO

```
.codex/skills/salesforce-analyst-Enerzee/    (SKILL.md + agents/openai.yaml)
.codex/skills/salesforce-architect-Enerzee/  (+ references/ com 2 baselines)
.codex/skills/salesforce-developer-Enerzee/  (SKILL.md + agents/openai.yaml)
```

**Avaliação**: são as versões **OpenAI Codex** dos mesmos 3 papéis que já existem em `.claude/commands/` (analyst, architect, developer). Última modificação: **01/Mar/2026** — congeladas. O próprio CLAUDE.md as descreve como *"Codex skills (legacy, kept for reference)"*.

**Problema**: duas fontes de verdade para os mesmos papéis. Se um padrão muda (ex: BO/DAO), você atualiza em dois lugares — e na prática só atualiza um, criando drift silencioso.

**Exceção que vale preservar**: as `references/` do architect Codex contêm baselines reais e úteis:
- `project-metadata-baseline.md` (data model da cadeia Opportunity)
- `default-architecture-pattern.md` (padrões recomendados)

Esses dois arquivos são citados no CLAUDE.md como docs-chave — **não jogue fora**, mova para `docs/` se for arquivar o resto.

---

### 1.4 `.claude/settings.local.json` — ⚠️ PRECISA LIMPEZA
**36 regras `allow` acumuladas.** Não é commitado (é local), mas está poluído.

A maioria é lixo de sessões antigas — regras hiper-específicas que nunca mais serão reusadas:
- Comandos `git commit` com heredoc gigante escapado de uma feature de março
- `git add` listando 14 arquivos `.cls` específicos (one-off de um PR de security)
- `brew install gh`, `git branch -D UAT`, etc.

**Avaliação**: regras one-off não deveriam virar `allow` permanente. Vale podar para deixar só as genéricas úteis (`Read(//Users/danielbelini/**)`, `Bash(git commit:*)`, `Bash(xargs git:*)`, scanner). Use `/fewer-permission-prompts` para gerar uma lista limpa.

---

### 1.5 Configuração global (`~/.claude/settings.json`) — contexto

Não é do projeto, mas afeta todas as sessões:
- `model: opus`, `effortLevel: xhigh`, `theme: light`
- **525 regras `allow`** acumuladas globalmente, `0 deny`, `0 ask`
- **Nenhum hook configurado**

Skills globais: `graphify`, `banner-design`, `brand` (as duas últimas do claudekit, não relacionadas ao Enerzee).
Commands globais: `compress`, `preserve`, `resume`, `project-note`, `evaluate-repository` (workflow Obsidian).

---

## 2. O que NÃO faz sentido (resumo crítico)

### 🔴 2.1 — API Key do Clockify commitada (AÇÃO URGENTE)
`.claude/commands/clockify.md` linha ~7:
```
- **API Key**: M2I2NjQ5MGIt...  ← em texto puro
- **Workspace ID**: 6911f737...
```
O arquivo **está rastreado pelo git** e não há `.gitignore` cobrindo `.claude/`. Significa que essa key está no histórico do repositório e em qualquer clone/fork.

**Plano de remediação:**
1. **Revogar a key** no painel do Clockify (assuma que vazou).
2. Gerar key nova e mover para fora do repo:
   - Variável de ambiente (`CLOCKIFY_API_KEY`), ou
   - Arquivo não-versionado lido pelo command.
3. Remover do `clockify.md` e referenciar a env var.
4. Limpar o histórico (`git filter-repo` ou BFG) — a key continua no histórico mesmo após editar o arquivo.

### 🟡 2.2 — Duplicação Codex vs Claude
3 skills Codex = 3 commands Claude. Manutenção duplicada, drift garantido. **Decida uma fonte de verdade.**

### 🟡 2.3 — Contradição no CLAUDE.md
Seção "Deployment Workflow" documenta `pr-validate.yml` + `merge-deploy.yml` (GitHub Actions), mas "Key Constraints" afirma *"No GitHub Actions — deployment is always manual"*. Uma das duas está errada — alinhar.

### 🟢 2.4 — Sobreposição deploy / pr-validate / merge-deploy
Os 3 reconstroem `package.xml` a partir do git diff de formas ligeiramente diferentes. Consolidar a lógica comum.

---

## 3. O que FAZ sentido (manter e valorizar)

- ✅ **CLAUDE.md** — espinha dorsal do contexto. Mantenha atualizado.
- ✅ **analyst / architect / developer / refactor** — papéis bem desenhados, com protocolos anti-alucinação (Passo 0 / Regra de ouro). Este é o coração da customização.
- ✅ **apex-review / flow-review / impact** — checklists que codificam os padrões reais do projeto e os riscos conhecidos (Lookups `required=false`, VRs inativas, `@future`).
- ✅ **jira** — template PT-BR pragmático.
- ✅ **references/ do architect Codex** — baselines de data model e arquitetura. Preservar mesmo que o resto do `.codex/` seja arquivado.
- ✅ **MEMORY.md (auto-memória)** — bem mantida, com regras de Apex (tabs, `--no-verify`, headers `@test`) e o plano de refactoring do OpportunityBO.

---

## 4. Recomendações priorizadas

| Prioridade | Ação | Esforço |
|-----------|------|---------|
| 🔴 P0 | Revogar key Clockify, remover do arquivo, limpar histórico git | 30 min |
| 🔴 P0 | Adicionar `.claude/settings.local.json` ao `.gitignore` (garantir que não vaze) | 2 min |
| 🟡 P1 | Corrigir contradição "No GitHub Actions" no CLAUDE.md | 5 min |
| 🟡 P1 | Decidir destino do `.codex/` — arquivar e mover `references/` p/ `docs/` | 15 min |
| 🟢 P2 | Consolidar deploy/pr-validate/merge-deploy (extrair lógica comum) | 1h |
| 🟢 P2 | Podar `settings.local.json` (rodar `/fewer-permission-prompts`) | 10 min |
| 🟢 P3 | Adicionar guard-rail de deploy em prod (hook ou regra `ask`) no merge-deploy | 30 min |

---

## 5. Como me deixar melhor neste projeto (sua pergunta direta)

1. **Tire segredos dos prompts.** Qualquer command que precise de credencial deve ler de env var — nunca embutir. Isso me deixa seguro de versionar.
2. **Uma fonte de verdade.** Escolha Claude *ou* Codex para os 3 papéis. Padrão duplicado = padrão que envelhece.
3. **Adicione guard-rails (hooks/`deny`/`ask`).** Hoje tenho `allow` para quase tudo e nada me impede de rodar um deploy em prod. Um `ask` em `sf project deploy ... prod` me deixa mais confiável.
4. **Mantenha o CLAUDE.md sem contradições.** Quando duas frases discordam, eu posso seguir a errada. Coerência > completude.
5. **Consolide comandos sobrepostos.** Menos comandos com responsabilidade clara > três comandos que fazem 70% a mesma coisa.

---

*Arquivo gerado por análise da estrutura `.claude/`, `.codex/`, `CLAUDE.md`, `settings.local.json` e configuração global.*
