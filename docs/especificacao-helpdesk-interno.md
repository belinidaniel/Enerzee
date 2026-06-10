# Especificação funcional - Help Desk interno

## Objetivo

Disponibilizar o Help Desk como aplicativo interno do Salesforce para que
funcionários abram e acompanhem chamados, enquanto gestores aprovam e administram
os casos sob sua responsabilidade.

## Escopo funcional

### HD-001 - Categorização simplificada

- O usuário informa o sistema e um único tipo.
- Todos os sistemas oferecem os tipos `Acesso`, `Melhoria`, `Erro` e `Dúvida`.
- `Subtipo` e `Prioridade` não aparecem no formulário de abertura.
- `Subtipo` não aparece no layout do Case.
- Por restrição nativa do objeto Case, `Priority` permanece no layout técnico
  como somente leitura, mas não faz parte da experiência do Help Desk.

**Critério de aceite:** um caso pode ser criado informando sistema, um dos quatro
tipos, assunto e descrição, sem subtipo ou prioridade.

### HD-002 - Acompanhamento de status

- A página não exibe `Com quem está` nem `Fluxo`.
- O acompanhamento apresenta separadamente:
  - status de aprovação: `Em aprovação`, `Aprovado` ou `Reprovado`;
  - status de execução proveniente do Jira, por exemplo `Em análise`,
    `Em andamento` ou `Finalizado`.
- O status operacional padrão do Case continua disponível no resumo técnico.

**Critério de aceite:** após a integração atualizar `JiraStatus__c`, o novo valor
é exibido no detalhe e na lista do chamado.

### HD-003 - Notificações

- O solicitante recebe e-mail quando houver alteração em `Status`,
  `StatusAprovacao__c` ou `JiraStatus__c`.
- Para chamados internos, o destinatário é o e-mail do usuário que criou o Case.
- Para chamados legados, o serviço tenta `SuppliedEmail` e depois o e-mail do
  contato.

**Critério de aceite:** cada transição de aprovação ou execução envia uma
notificação contendo o número do caso e os status atuais.

### HD-004 - Aprovação gerencial

- O aprovador é o `ManagerId` ativo do usuário que abriu o chamado.
- Quando o usuário não possui gestor ativo, o aprovador padrão é o usuário ativo
  com e-mail `elenara.rodrigues@enerzee.com.br`.
- O Case registra o gestor resolvido em `Gerente__c`.

**Critério de aceite:** um chamado novo entra no processo
`AprovacaoHelpDeskGerente` e é atribuído ao gestor ou ao aprovador padrão.

### HD-005 - Aplicativo e acesso

- O aplicativo Lightning `Help Desk` contém a aba principal do componente e a
  aba de Cases.
- Funcionários podem criar chamados e acompanhar apenas os próprios casos.
- Gestores podem consultar e editar todos os casos de Help Desk.
- O acesso gerencial é identificado pela Custom Permission
  `HelpDesk_Manager`.

**Critério de aceite:** um funcionário não acessa o detalhe de um caso criado
por outro funcionário; um gestor autorizado consegue acessar e editar todos.

## Perfis de acesso

| Público      | Permission Set             | Acesso                                                      |
| ------------ | -------------------------- | ----------------------------------------------------------- |
| Funcionários | `HelpDesk_Usuario_Interno` | Aplicativo, criação de Case e leitura dos próprios chamados |
| Gestores     | `HelpDesk_Aprovacao_Admin` | Custom Permission gerencial, leitura e edição dos chamados  |

O compartilhamento dos casos de Help Desk com edição é feito para o grupo
público `HelpDesk_Managers`.

## Checklist pós-deploy

1. Atribuir `HelpDesk_Usuario_Interno` aos funcionários que usarão o aplicativo.
2. Atribuir `HelpDesk_Aprovacao_Admin` aos gestores.
3. Incluir os mesmos gestores no grupo público `HelpDesk_Managers`.
4. Confirmar que Elenara possui usuário ativo com o e-mail configurado.
5. Confirmar que todos os funcionários possuem `ManagerId` atualizado.
6. Validar que a integração Jira preenche `Case.JiraStatus__c`.
7. Executar testes de abertura, aprovação, reprovação e atualização pelo Jira.
8. Validar o recebimento dos e-mails em cada mudança de status.

## Fora de escopo

- Alterar o mecanismo da integração Jira além do consumo de `JiraStatus__c`.
- Migrar ou apagar valores históricos de subtipo e prioridade.
- Remover fisicamente o campo padrão `Case.Priority`.
