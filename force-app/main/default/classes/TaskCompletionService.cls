/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-17-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class TaskCompletionService {
    private static final String QUEUE_DEVELOPER_NAME_CONTRATOS = 'Contratos';
    private static final String QUEUE_DEVELOPER_NAME_VIABILIDADE = 'AnalistaViabilidade';
    private static final String SUBJECT_DOC_COM = 'VERIFICAR DOCUMENTAÇÃO COMERCIAL';
    private static final String SUBJECT_VIABILIDADE = 'VERIFICAR VIABILIDADE TÉCNICA';
    private static final String SUBJECT_DELEGAR_GESTOR_OBRAS = 'DELEGAR GESTOR DE OBRAS';
    private static Map<String, Id> queueCache = new Map<String, Id>();

    public class CompletionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id followUpId;
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
        query += ' FROM Task WHERE Id = :taskId';
        Task t = (Task)Database.query(query);

        // Validação de documentos obrigatórios por atividade (via CMDT)
        ensureRequiredDocuments(t);

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

        if (t.WhatId != null) {
            try {
                String whatType = t.WhatId.getSObjectType().getDescribe().getName();
                Boolean flagDocTask = false;
                Boolean flagViabTask = false;
                String pendDocTask = null;
                String pendViabTask = null;
                if (Schema.sObjectType.Task.fields.getMap().containsKey('DocumentacaoComercialCriarAtividadeContratos__c')) {
                    flagDocTask = (Boolean)t.get('DocumentacaoComercialCriarAtividadeContratos__c');
                }
                if (Schema.sObjectType.Task.fields.getMap().containsKey('CriarAtividadeViabilidadeTecnica__c')) {
                    flagViabTask = (Boolean)t.get('CriarAtividadeViabilidadeTecnica__c');
                }
                if (Schema.sObjectType.Task.fields.getMap().containsKey('DocumentacaoComercialPendencia__c')) {
                    pendDocTask = (String)t.get('DocumentacaoComercialPendencia__c');
                }
                if (Schema.sObjectType.Task.fields.getMap().containsKey('ViabilidadeTecnicaPendencia__c')) {
                    pendViabTask = (String)t.get('ViabilidadeTecnicaPendencia__c');
                }

                if (whatType == 'Projeto__c' || whatType == 'Instalacao__c') {
                    Projeto__c proj = null;
                    if (whatType == 'Projeto__c') {
                        proj = [
                            SELECT DocumentacaoComercialPendencia__c,
                                DocumentacaoCriarAtividadeContratos__c,
                                ViabilidadeTecnicaPendencia__c,
                                CriarAtividadeViabilidadeTecnica__c
                            FROM Projeto__c
                            WHERE Id = :t.WhatId
                            LIMIT 1
                        ];
                    } else {
                        proj = [
                            SELECT DocumentacaoComercialPendencia__c,
                                DocumentacaoCriarAtividadeContratos__c,
                                ViabilidadeTecnicaPendencia__c,
                                CriarAtividadeViabilidadeTecnica__c
                            FROM Projeto__c
                            WHERE Id IN (
                                SELECT Projeto__c FROM Instalacao__c WHERE Id = :t.WhatId
                            )
                            LIMIT 1
                        ];
                    }

                    if (proj != null) {
                        Boolean isDocComSubject = subjectEquals(t.Subject, SUBJECT_DOC_COM);
                        Boolean isViabilidadeSubject = subjectEquals(t.Subject, SUBJECT_VIABILIDADE);

                        docPendencia = String.isNotBlank(pendDocTask) ? pendDocTask : proj.DocumentacaoComercialPendencia__c;
                        viabilidadePendencia = String.isNotBlank(pendViabTask) ? pendViabTask : proj.ViabilidadeTecnicaPendencia__c;
                        autoFollowUpContratos = isDocComSubject && (flagDocTask || proj.DocumentacaoCriarAtividadeContratos__c);
                        autoFollowUpViabilidade = isViabilidadeSubject && (flagViabTask || proj.CriarAtividadeViabilidadeTecnica__c);

                        if (resolvedFollowUpOwnerId == null) {
                            if (autoFollowUpContratos) {
                                resolvedFollowUpOwnerId = getQueueId(QUEUE_DEVELOPER_NAME_CONTRATOS);
                            } else if (autoFollowUpViabilidade) {
                                resolvedFollowUpOwnerId = getQueueId(QUEUE_DEVELOPER_NAME_VIABILIDADE);
                            }
                        }
                    }
                }
                if (whatType == 'Instalacao__c' && subjectEquals(t.Subject, SUBJECT_DELEGAR_GESTOR_OBRAS)) {
                    InstalacaoTaskBO.createPlanningTasksAfterDelegar(t.WhatId);
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
            result.followUpId = followUp.Id;
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

    /**
     * Garante que todos os documentos configurados para o Subject da atividade foram anexados
     * (OpportunityAttachmentLink__c) com ActivityName__c = Subject e SObjectId__c = WhatId.
     */
    @TestVisible
    private static void ensureRequiredDocuments(Task t) {
        if (t == null || String.isBlank(t.Subject) || t.WhatId == null) {
            return;
        }

        List<ActivityRequiredDocument__mdt> configs = [
            SELECT ActivitySubject__c, RequiredFiles__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c = :t.Subject
        ];
        if (configs.isEmpty()) {
            return;
        }

        // Normaliza nomes requeridos
        Set<String> required = new Set<String>();
        for (ActivityRequiredDocument__mdt cfg : configs) {
            if (String.isBlank(cfg.RequiredFiles__c)) {
                continue;
            }
            for (String name : cfg.RequiredFiles__c.split(';')) {
                String norm = normalizeName(name);
                if (!String.isBlank(norm)) {
                    required.add(norm);
                }
            }
        }
        if (required.isEmpty()) {
            return;
        }

        // Recupera anexos já enviados
        Set<String> uploaded = new Set<String>();
        for (OpportunityAttachmentLink__c link : [
            SELECT AttachmentDescription__c
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(t.WhatId)
                AND ActivityName__c = :t.Subject
        ]) {
            String norm = normalizeName(link.AttachmentDescription__c);
            if (!String.isBlank(norm)) {
                uploaded.add(norm);
            }
        }

        Set<String> missing = required.clone();
        missing.removeAll(uploaded);
        if (!missing.isEmpty()) {
            String msg = 'Ainda faltam anexar os documentos obrigatórios: ' + String.join(new List<String>(missing), ', ');
            throw new AuraHandledException(msg);
        }
    }

    @TestVisible
    private static String normalizeName(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String normalized = value.toLowerCase();
        // remove acentos comuns
        normalized = normalized
            .replaceAll('[áàãâä]', 'a')
            .replaceAll('[éèêë]', 'e')
            .replaceAll('[íìîï]', 'i')
            .replaceAll('[óòõôö]', 'o')
            .replaceAll('[úùûü]', 'u')
            .replaceAll('[ç]', 'c');
        // substitui não alfanuméricos por underscore e remove underscores nas bordas
        normalized = normalized.replaceAll('[^a-z0-9]+', '_');
        normalized = normalized.replaceAll('^_+|_+$', '');
        return normalized;
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
