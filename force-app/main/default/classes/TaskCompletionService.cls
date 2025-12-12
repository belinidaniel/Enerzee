public with sharing class TaskCompletionService {
    public class CompletionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static CompletionResult completeWithComment(Id taskId, String commentBody) {
        if (taskId == null) {
            throw new AuraHandledException('Task Id is required.');
        }

        Task t = [
            SELECT Id, WhatId, Status, IsClosed, Subject
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

        result.success = true;
        result.message = 'Atividade concluída com sucesso.';
        return result;
    }
}
