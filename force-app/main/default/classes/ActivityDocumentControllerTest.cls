@IsTest
private class ActivityDocumentControllerTest {

    @IsTest
    static void shouldReturnEmptyWhenNoSubjectOrId() {
        System.assertEquals(0, ActivityDocumentController.getRequiredDocuments(null).size());
        System.assertEquals(0, ActivityDocumentController.getAttachments(null, null).size());
        System.assertEquals(0, ActivityDocumentController.getDocumentCompletionStates(null, null).size());
    }

    @IsTest
    static void shouldReturnTaskContextForOpportunity() {
        Account acc = new Account(Name = 'ACC');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            IdVirtualOffice__c = 'test-vo'
        );
        insert opp;

        Task t = new Task(Subject = 'Teste', WhatId = opp.Id, Status = 'Not Started');
        insert t;

        Test.startTest();
        ActivityDocumentController.TaskContext ctx = ActivityDocumentController.getTaskContext(t.Id);
        Test.stopTest();

        System.assertEquals('Teste', ctx.subject);
        System.assertEquals(opp.Id, ctx.whatId);
        System.assertEquals(opp.Id, ctx.opportunityId);
        System.assertEquals('test-vo', ctx.idVirtualOffice);
    }

    @IsTest
    static void shouldFallbackRequiredDocumentsForLegacySubject() {
        Test.startTest();
        List<ActivityDocumentController.RequiredDoc> docs = ActivityDocumentController.getRequiredDocuments(
            TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA_LEGACY
        );
        Test.stopTest();

        System.assert(!docs.isEmpty(), 'Deve retornar documentos também para o assunto legado.');
    }

    @IsTest
    static void shouldSetAndUnsetCompletionState() {
        Account acc = new Account(Name = 'Conta Docs');
        insert acc;

        String subject = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA;
        String docName = 'MOBILIZAÇÃO/CONFERÊNCIA DE MATERIAIS';

        insert new OpportunityAttachmentLink__c(
            Name = 'Evidencia 1',
            SObjectId__c = String.valueOf(acc.Id),
            ActivityName__c = subject,
            AttachmentDescription__c = 'foto_1.jpg',
            DocRequiredName__c = docName,
            AttachmentURL__c = 'https://example.com/foto_1.jpg'
        );

        Test.startTest();
        ActivityDocumentController.CompletionStateItem completed = ActivityDocumentController.setDocumentCompleted(
            acc.Id,
            subject,
            docName,
            true
        );
        ActivityDocumentController.CompletionStateItem uncompleted = ActivityDocumentController.setDocumentCompleted(
            acc.Id,
            subject,
            docName,
            false
        );
        Test.stopTest();

        System.assertEquals(true, completed.completed, 'O item deve estar concluído após marcar.');
        System.assertNotEquals(null, completed.completedById, 'Usuário de conclusão deve ser preenchido.');
        System.assertEquals(false, uncompleted.completed, 'O item deve voltar a não concluído.');
        System.assertEquals(null, uncompleted.completedById, 'Usuário deve ser limpo ao desmarcar.');
    }

    @IsTest
    static void shouldBlockCompletionWhenEvidenceIsMissing() {
        Account acc = new Account(Name = 'Conta Sem Evidencia');
        insert acc;

        Boolean hasException = false;
        try {
            ActivityDocumentController.setDocumentCompleted(
                acc.Id,
                TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA,
                'DOC SEM EVIDENCIA',
                true
            );
        } catch (AuraHandledException ex) {
            hasException = true;
        }
        System.assertEquals(true, hasException, 'Conclusão sem evidência deve ser bloqueada.');
    }

    @IsTest
    static void shouldDeleteAttachmentAndResetCompletion() {
        Account acc = new Account(Name = 'Conta Remove');
        insert acc;

        String subject = TaskUtils.SUBJECT_RELATORIO_DE_EXECUCAO_DE_OBRA;
        String docName = 'COMISSIONAMENTO';

        OpportunityAttachmentLink__c evidence = new OpportunityAttachmentLink__c(
            Name = 'Evidencia para remover',
            SObjectId__c = String.valueOf(acc.Id),
            ActivityName__c = subject,
            AttachmentDescription__c = 'foto_remove.jpg',
            DocRequiredName__c = docName,
            AttachmentURL__c = 'https://example.com/foto_remove.jpg'
        );
        insert evidence;

        ActivityDocumentController.setDocumentCompleted(acc.Id, subject, docName, true);

        Test.startTest();
        Boolean removed = ActivityDocumentController.deleteAttachment(evidence.Id);
        Test.stopTest();

        System.assertEquals(true, removed, 'A remoção do anexo deve retornar true.');
        Integer evidenceCount = [
            SELECT COUNT()
            FROM OpportunityAttachmentLink__c
            WHERE Id = :evidence.Id
        ];
        System.assertEquals(0, evidenceCount, 'O anexo removido não deve mais existir.');

        OpportunityAttachmentLink__c state = [
            SELECT Completed__c, CompletedDate__c, CompletedBy__c
            FROM OpportunityAttachmentLink__c
            WHERE SObjectId__c = :String.valueOf(acc.Id)
                AND ActivityName__c = :subject
                AND DocRequiredName__c = :docName
                AND IsChecklistState__c = true
            LIMIT 1
        ];
        System.assertEquals(false, state.Completed__c, 'Ao remover a última evidência, a conclusão deve ser limpa.');
        System.assertEquals(null, state.CompletedDate__c, 'Data de conclusão deve ser limpa.');
        System.assertEquals(null, state.CompletedBy__c, 'Usuário de conclusão deve ser limpo.');
    }
}
