public with sharing class TaskCompletionService {
    public class CompletionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isTaskClosed(Id taskId) {
        if (taskId == null) {
            return false;
        }
        Task t = [
            SELECT Id, IsClosed, Status
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];
        return t.IsClosed || (t.Status != null && t.Status.toLowerCase() == 'completed');
    }

    @AuraEnabled
    public static CompletionResult completeWithComment(Id taskId, String commentBody, Boolean createFollowUp, Id followUpOwnerId) {
        if (taskId == null) {
            throw new AuraHandledException('Task Id is required.');
        }

        Task t = [
            SELECT Id, WhatId, Status, IsClosed, Subject, OwnerId
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];

        CompletionResult result = new CompletionResult();

        // Atualiza status para Completed
        t.Status = TaskUtils.STATUS_CONCLUIDO;
        update t;

        // Publica comentário no feed do registro relacionado, se houver
        if (t.WhatId != null && !String.isBlank(commentBody)) {
            FeedItem post = new FeedItem();
            post.ParentId = t.WhatId;
            post.Body = UserInfo.getName() + ' comentou na atividade \"' + (t.Subject == null ? '' : t.Subject) + '\": ' + commentBody;
            insert post;
        }

        if (createFollowUp == true) {
            String followUpDescription = commentBody;

            if (t.WhatId != null) {
                try {
                    String whatType = t.WhatId.getSObjectType().getDescribe().getName();
                    if (whatType == 'Projeto__c') {
                        Projeto__c proj = [
                            SELECT DocumentacaoComercialPendencia__c
                            FROM Projeto__c
                            WHERE Id = :t.WhatId
                            LIMIT 1
                        ];
                        if (!String.isBlank(proj.DocumentacaoComercialPendencia__c)) {
                            if (!String.isBlank(followUpDescription)) {
                                followUpDescription += '\n\n';
                            }
                            followUpDescription += 'Documentação faltante: ' + proj.DocumentacaoComercialPendencia__c;
                        }
                    }
                } catch (Exception ignore) {
                    // não bloqueia a criação da tarefa de follow-up
                }
            }

            Task followUp = new Task();
            followUp.Subject = 'Follow-up: ' + (t.Subject == null ? 'Atividade' : t.Subject);
            followUp.WhatId = t.WhatId;
            followUp.OwnerId = followUpOwnerId != null ? followUpOwnerId : t.OwnerId;
            followUp.Description = followUpDescription;
            followUp.Status = 'Not Started';
            followUp.Priority = 'Normal';
            followUp.ActivityDate = Date.today();
            insert followUp;
        }

        result.success = true;
        result.message = 'Atividade concluída com sucesso.';
        return result;
    }
}
