# Caderno de Teste - SLA de Tasks

Data: 2026-02-11

**Objetivo**
Validar notificacoes e resumos de SLA de Tasks com regras centralizadas, configuraveis e auditaveis.

**Ambiente**
Sandbox/Developer. Deliverability habilitado para envio de email de teste. Usuario com permissao para Log__c e Custom Metadata.

**Pre-condicoes**
1. Deploy realizado de todas as classes, Custom Metadata Types e registros.
2. Campos em Task disponiveis: `HoraVencimento__c`, `NotificadoAntesVencer__c`, `NotificadoAposVencer__c`.
3. Custom Notification Type existente na org (usar DeveloperName em `CustomNotificationTypeDeCustomNotificationTypeDevName__cvName__c` quando aplicavel).
4. Pelo menos uma fila com Task habilitado (QueueSobject com `Task`).
5. Usuarios de teste ativos com email valido e um gestor configurado.

**Dados base sugeridos**
1. Usuario `Gestor_Teste` (ativo).
2. Usuario `Owner_Teste` (ativo, ManagerId = Gestor_Teste).
3. Usuario `Owner_SemGestor` (ativo, ManagerId vazio).
4. Fila `SLA_TEST_QUEUE` com email configurado e membro `Owner_Teste`.

**Comandos Apex de disparo rapido**
```apex
// Notificacoes de vencimento
List<Task> tasks = [SELECT Id, OwnerId, Status, ActivityDate, Subject, Priority, TaskSubtype, Type,
                           HoraVencimento__c, NotificadoAntesVencer__c, NotificadoAposVencer__c
                    FROM Task
                    WHERE Subject LIKE 'SLA TEST%'];
TaskSlaNotificationService.processDeadlineNotifications(tasks);

// Resumos diarios
TaskSlaDailySummaryService.runManagerOverdue();
TaskSlaDailySummaryService.runManagerDueTomorrow();
TaskSlaDailySummaryService.runOwnerOpenSummary();
```

**Consulta de auditoria**
```soql
SELECT Id, Name, Type__c, RelatedId__c, Message__c, CreatedDate
FROM Log__c
WHERE Type__c LIKE 'TASK_%'
ORDER BY CreatedDate DESC
```

**Cenarios**
1. C1 - Notificacao 30 min antes para Owner + Manager. Objetivo: validar envio e log duplo. Pre-condicao: `TASK_BEFORE_DUE` Enabled, NotifyOwner true, NotifyManager true, MinutesBeforeDue 30. Passos: criar Task com `ActivityDate` hoje, `HoraVencimento__c` em 20 min, Owner = `Owner_Teste`, Status Open, `NotificadoAntesVencer__c = false`. Executar `TaskSlaNotificationService.processDeadlineNotifications`. Resultado esperado: `NotificadoAntesVencer__c = true` e 2 logs `Type__c = TASK_BEFORE_DUE` (Owner + Manager).
2. C2 - Notificacao 30 min antes sem gestor. Objetivo: enviar so para Owner. Pre-condicao: Owner sem Manager. Passos: mesma Task com Owner = `Owner_SemGestor`. Resultado esperado: 1 log e nenhuma falha.
3. C3 - Notificacao 30 min antes para fila com membros. Objetivo: enviar para membros da fila. Pre-condicao: `SLA_TEST_QUEUE` com membro ativo, roteamento DEFAULT MEMBERS. Passos: Task com Owner = `SLA_TEST_QUEUE`. Resultado esperado: logs para cada membro, `NotificadoAntesVencer__c = true`.
4. C4 - Fallback de fila por email. Objetivo: quando sem membros, usar email da fila. Pre-condicao: fila sem membros, `SLA_Queue_Routing_Config__mdt.DEFAULT` com Fallback `QUEUE_EMAIL`. Passos: Task com Owner = fila e email configurado. Resultado esperado: log com `RecipientEmail=` e `NotificadoAntesVencer__c = true`.
5. C5 - Notificacao apos vencimento. Objetivo: validar `TASK_AFTER_DUE`. Pre-condicao: `TASK_AFTER_DUE` Enabled. Passos: Task com `HoraVencimento__c` no passado, `NotificadoAposVencer__c = false`. Resultado esperado: `NotificadoAposVencer__c = true` e log `TASK_AFTER_DUE`.
6. C6 - Config desabilitada. Objetivo: nao enviar quando `Enabled__c = false`. Passos: desabilitar `TASK_BEFORE_DUE`, repetir C1. Resultado esperado: sem logs e sem atualizacao dos campos de notificacao.
7. C7 - Filtro por SubjectContains. Objetivo: filtrar por assunto. Pre-condicao: `TASK_BEFORE_DUE.SubjectContains__c = Follow-up`. Passos: Task com Subject sem "Follow-up". Resultado esperado: nenhuma notificacao e sem log.
8. C8 - Filtro por Priority/Type/TaskSubtype. Objetivo: aplicar filtros combinados. Pre-condicao: setar `PriorityIn__c`, `TaskTypeIn__c`, `TaskSubtypeIn__c` na config. Passos: criar Task fora do filtro. Resultado esperado: sem notificacao e sem log.
9. C9 - Filtro por QueueDeveloperNames. Objetivo: limitar filas especificas. Pre-condicao: setar `QueueDeveloperNames__c = SLA_TEST_QUEUE`. Passos: Task em fila diferente. Resultado esperado: sem notificacao.
10. C10 - Status fechado/cancelado. Objetivo: excluir por status. Pre-condicao: `SLA_Status_Config__mdt` com Completed/Cancelada. Passos: Task com Status Completed e outra com Cancelada. Resultado esperado: nenhuma notificacao nem log.
11. C11 - Resumo diario gestor atrasadas. Objetivo: gerar resumo por Manager. Pre-condicao: `TASK_DAILY_MANAGER_OVERDUE` Enabled, NotifyManager true. Passos: Task com ActivityDate < hoje para Owner com Manager. Executar `TaskSlaDailySummaryService.runManagerOverdue()`. Resultado esperado: log `TASK_DAILY_MANAGER_OVERDUE` para Manager e email enviado.
12. C12 - Resumo diario gestor vencem amanha. Objetivo: validar conjunto de amanha. Passos: Task com ActivityDate = amanha. Executar `runManagerDueTomorrow()`. Resultado esperado: log `TASK_DAILY_MANAGER_DUE_TOMORROW`.
13. C13 - Resumo diario de abertos para Owner. Objetivo: email com buckets. Passos: criar tasks com ActivityDate ontem, hoje, amanha, futura e null. Executar `runOwnerOpenSummary()`. Resultado esperado: log `TASK_DAILY_OWNER_OPEN` e email com buckets incluindo "Sem data".
14. C14 - Resumo diario para fila. Objetivo: enviar para fila conforme roteamento. Passos: tasks abertas com Owner = fila. Executar `runOwnerOpenSummary()`. Resultado esperado: logs e emails conforme MEMBERS/QUEUE_EMAIL.
15. C15 - Nao enviar email vazio. Objetivo: evitar envios sem tarefas. Passos: garantir nenhum registro para o conjunto e executar os metodos. Resultado esperado: nenhum log criado.
16. C16 - SendEmail off, SendBell on. Objetivo: apenas sino. Pre-condicao: `TASK_BEFORE_DUE.SendEmail__c = false` e `SendBell__c = true`. Passos: repetir C1. Resultado esperado: log criado e notificacao no sino, sem email.
17. C17 - Custom Notification Type invalido. Objetivo: fallback para primeiro tipo. Pre-condicao: `CustomNotificationTypeDevName__c` com valor inexistente. Passos: disparar notificacao. Resultado esperado: sem erro e notificacao no sino usando tipo default.
18. C18 - Deduplicacao Owner = Manager. Objetivo: evitar duplicidade. Passos: configurar Owner com ManagerId igual ao proprio usuario (se permitido) e disparar notifica. Resultado esperado: apenas 1 log para o mesmo usuario.

**Validacao adicional**
1. Confirmar atualizacao de `NotificadoAntesVencer__c` e `NotificadoAposVencer__c` nas Tasks.
2. Confirmar que `Log__c` registra `Type__c`, `RelatedId__c` e `Message__c` corretamente.
3. Confirmar que filtros de configuracao (status, subject, prioridade, tipo, fila) refletem o comportamento esperado.

**Observacoes**
1. O calculo de data usa timezone do org (padrao). Ajustar se houver exigencia diferente.
2. O envio de email pode depender de Deliverability e limites diarios da org.
