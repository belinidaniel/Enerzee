public with sharing class TaskCompletionService {
    private static final String QUEUE_DEVELOPER_NAME_CONTRATOS = 'Contratos';
    private static final String QUEUE_DEVELOPER_NAME_VIABILIDADE = 'AnalistaViabilidade';
    private static final String SUBJECT_DOC_COM = 'VERIFICAR DOCUMENTAÇÃO COMERCIAL';
    private static final String SUBJECT_VIABILIDADE = 'VERIFICAR VIABILIDADE TÉCNICA';
    private static Map<String, Id> queueCache = new Map<String, Id>();

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

        Boolean hasDispensaFields = Schema.sObjectType.Task.fields.getMap().containsKey('DispensarAtividade__c');
        String query = 'SELECT Id, WhatId, Status, IsClosed, Subject, OwnerId';
        if (hasDispensaFields) {
            query += ', DispensarAtividade__c, MotivoDispensa__c';
        }
        query += ' FROM Task WHERE Id = :taskId';
        Task t = (Task)Database.query(query);

        CompletionResult result = new CompletionResult();
        Boolean shouldCreateFollowUp = createFollowUp == true;
        Boolean autoFollowUpContratos = false;
        Boolean autoFollowUpViabilidade = false;
        String docPendencia = null;
        String viabilidadePendencia = null;
        String followUpDescription = commentBody;
        Id resolvedFollowUpOwnerId = followUpOwnerId;

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

        // Se atividade foi dispensada, registrar motivo e não criar follow-up
        if (hasDispensaFields) {
            Boolean dispensa = (Boolean)t.get('DispensarAtividade__c');
            if (dispensa == true) {
                String motivo = (String)t.get('MotivoDispensa__c');
                if (t.WhatId != null && !String.isBlank(motivo)) {
                    FeedItem dispenseNote = new FeedItem();
                    dispenseNote.ParentId = t.WhatId;
                    dispenseNote.Body = 'Atividade "' + (t.Subject == null ? '' : t.Subject) + '" dispensada. Motivo: ' + motivo;
                    insert dispenseNote;
                }

                result.success = true;
                result.message = 'Atividade dispensada.';
                return result;
            }
        }

        if (t.WhatId != null) {
            try {
                String whatType = t.WhatId.getSObjectType().getDescribe().getName();
                if (whatType == 'Projeto__c') {
                    Projeto__c proj = [
                        SELECT DocumentacaoComercialPendencia__c,
                            DocumentacaoCriarAtividadeContratos__c,
                            ViabilidadeTecnicaPendencia__c,
                            CriarAtividadeViabilidadeTecnica__c
                        FROM Projeto__c
                        WHERE Id = :t.WhatId
                        LIMIT 1
                    ];

                    Boolean isDocComSubject = subjectEquals(t.Subject, SUBJECT_DOC_COM);
                    Boolean isViabilidadeSubject = subjectEquals(t.Subject, SUBJECT_VIABILIDADE);

                    docPendencia = proj.DocumentacaoComercialPendencia__c;
                    viabilidadePendencia = proj.ViabilidadeTecnicaPendencia__c;
                    autoFollowUpContratos = isDocComSubject && proj.DocumentacaoCriarAtividadeContratos__c;
                    autoFollowUpViabilidade = isViabilidadeSubject && proj.CriarAtividadeViabilidadeTecnica__c;

                    if (resolvedFollowUpOwnerId == null) {
                        if (autoFollowUpContratos) {
                            resolvedFollowUpOwnerId = getQueueId(QUEUE_DEVELOPER_NAME_CONTRATOS);
                        } else if (autoFollowUpViabilidade) {
                            resolvedFollowUpOwnerId = getQueueId(QUEUE_DEVELOPER_NAME_VIABILIDADE);
                        }
                    }
                }
            } catch (Exception ignore) {
                // não bloqueia a criação da tarefa de follow-up
            }
        }

        shouldCreateFollowUp = shouldCreateFollowUp || autoFollowUpContratos || autoFollowUpViabilidade;

        if (shouldCreateFollowUp) {
            if (!String.isBlank(docPendencia) && subjectEquals(t.Subject, SUBJECT_DOC_COM)) {
                followUpDescription = appendNote(followUpDescription, 'Documentação faltante: ' + docPendencia);
            }
            if (!String.isBlank(viabilidadePendencia) && subjectEquals(t.Subject, SUBJECT_VIABILIDADE)) {
                followUpDescription = appendNote(followUpDescription, 'Pendências da viabilidade técnica: ' + viabilidadePendencia);
            }

            Task followUp = new Task();
            followUp.Subject = 'Follow-up: ' + (t.Subject == null ? 'Atividade' : t.Subject);
            followUp.WhatId = t.WhatId;
            followUp.OwnerId = resolvedFollowUpOwnerId != null ? resolvedFollowUpOwnerId : t.OwnerId;
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

    private static Boolean subjectEquals(String value, String expected) {
        if (String.isBlank(value) || String.isBlank(expected)) {
            return false;
        }
        return value.trim().toLowerCase() == expected.trim().toLowerCase();
    }

    private static String appendNote(String baseText, String note) {
        if (String.isBlank(note)) {
            return baseText;
        }
        if (String.isBlank(baseText)) {
            return note;
        }
        return baseText + '\n\n' + note;
    }

    private static Id getQueueId(String developerName) {
        if (String.isBlank(developerName)) {
            return null;
        }
        if (!queueCache.containsKey(developerName)) {
            try {
                Group queue = [
                    SELECT Id
                    FROM Group
                    WHERE Type = 'Queue'
                        AND DeveloperName = :developerName
                    LIMIT 1
                ];
                queueCache.put(developerName, queue.Id);
            } catch (Exception e) {
                // cache null to avoid repeated queries
                queueCache.put(developerName, null);
            }
        }
        return queueCache.get(developerName);
    }
}
