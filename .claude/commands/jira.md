# Gerar Ticket Jira — Enerzee

Gere um ticket Jira estruturado e completo baseado no input abaixo.

## Input

$ARGUMENTS

## Formato obrigatório de saída

Produza o ticket no seguinte formato (pronto para copiar e colar no Jira):

---

**Tipo**: História / Bug / Tarefa Técnica / Spike _(escolha o correto)_

**Título**: [Verbo no infinitivo] + [objeto] + [contexto] _(máximo 80 chars)_

**Descrição**

### Contexto

_Por que esse trabalho é necessário? Qual problema resolve?_

### Objetivo

_O que deve ser verdade quando esse item for concluído?_

### Escopo

## **In-scope:**

## **Out-of-scope:**

### Critérios de Aceite

```
Dado que [pré-condição]
Quando [ação]
Então [resultado esperado]
```

_(Adicione múltiplos cenários: positivo, negativo, borda)_

### Notas Técnicas

_Objetos Salesforce envolvidos, classes relevantes, flows relacionados, risks_

### Dependências

_Tickets bloqueantes, validações externas necessárias, aprovações_

### Estimativa

_Story Points sugeridos (1/2/3/5/8/13) com justificativa_

---

## Regras

- Se o input for uma conversa ou anotação informal, normalize antes de gerar
- Identifique o objeto Salesforce principal da cadeia envolvida (Opportunity, ViabilityStudy**c, Projeto**c, Instalacao\_\_c)
- Marque explicitamente dependências com SAP, ClickSign, ou Nivello se relevante
- Se a demanda for ambígua, liste as questões em aberto no final antes dos critérios de aceite
- O ticket deve ser auto-explicativo — qualquer desenvolvedor do time deve entendê-lo sem contexto adicional
