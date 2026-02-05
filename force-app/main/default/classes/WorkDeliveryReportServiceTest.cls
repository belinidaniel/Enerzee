@isTest
private class WorkDeliveryReportServiceTest {

    @isTest
    static void testAutoGenerateReportOnStatusChange() {
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        Instalacao__c inst = createInstallation(opp.Id, 'Planejamento de Obra');
        createFinalReportTask(inst.Id);
        createTemplateWithFiles();

        List<String> requiredDocs = loadRequiredDocs();
        createExternalAttachments(inst.Id, requiredDocs, null);

        Test.setMock(HttpCalloutMock.class, new AzureBlobMock());

        Test.startTest();
        inst.Status__c = WorkDeliveryReportService.STATUS_OBRA_CONCLUIDA;
        update inst;
        Test.stopTest();

        Instalacao__c saved = [
            SELECT Id, WorkDeliveryReportGenerated__c, WorkDeliveryReportContentDocumentId__c, WorkDeliveryReportLastError__c
            FROM Instalacao__c
            WHERE Id = :inst.Id
        ];

        System.assertEquals(true, saved.WorkDeliveryReportGenerated__c, 'Report should be generated.');
        System.assertNotEquals(null, saved.WorkDeliveryReportContentDocumentId__c, 'ContentDocument should be linked.');
        System.assertEquals(null, saved.WorkDeliveryReportLastError__c, 'No error should be stored.');

        ContentDocumentLink link = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :inst.Id
                AND ContentDocumentId = :saved.WorkDeliveryReportContentDocumentId__c
            LIMIT 1
        ];
        System.assertEquals(inst.Id, link.LinkedEntityId, 'Link should target installation.');

        ContentVersion reportVersion = [
            SELECT Title
            FROM ContentVersion
            WHERE ContentDocumentId = :saved.WorkDeliveryReportContentDocumentId__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(reportVersion.Title.startsWith('Relatório de Entrega de Obra - '), 'Report title should follow pattern.');
        System.assert(reportVersion.Title.contains(opp.Name), 'Report title should include opportunity name.');
    }

    @isTest
    static void testMissingDocumentsSkipsGeneration() {
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        Instalacao__c inst = createInstallation(opp.Id, 'Planejamento de Obra');
        createFinalReportTask(inst.Id);
        createTemplateWithFiles();

        List<String> requiredDocs = loadRequiredDocs();
        createExternalAttachments(inst.Id, requiredDocs, 0);

        Test.setMock(HttpCalloutMock.class, new AzureBlobMock());

        Test.startTest();
        inst.Status__c = WorkDeliveryReportService.STATUS_OBRA_CONCLUIDA;
        update inst;
        Test.stopTest();

        Instalacao__c saved = [
            SELECT Id, WorkDeliveryReportGenerated__c, WorkDeliveryReportContentDocumentId__c, WorkDeliveryReportLastError__c
            FROM Instalacao__c
            WHERE Id = :inst.Id
        ];

        System.assertEquals(false, saved.WorkDeliveryReportGenerated__c, 'Report should not be generated.');
        System.assertEquals(null, saved.WorkDeliveryReportContentDocumentId__c, 'No ContentDocument should be linked.');
        System.assertNotEquals(null, saved.WorkDeliveryReportLastError__c, 'Error should be recorded.');
        System.assert(saved.WorkDeliveryReportLastError__c.contains(requiredDocs[0]), 'Missing doc should be mentioned.');
    }

    @isTest
    static void testIdempotentWhenAlreadyGenerated() {
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        Instalacao__c inst = createInstallation(opp.Id, 'Planejamento de Obra');
        inst.WorkDeliveryReportGenerated__c = true;
        update inst;

        Test.startTest();
        inst.Status__c = WorkDeliveryReportService.STATUS_OBRA_CONCLUIDA;
        update inst;
        Test.stopTest();

        Integer reportCount = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE Title LIKE 'Relatório de Entrega de Obra - %'
        ];
        System.assertEquals(0, reportCount, 'No new report should be generated.');
    }

    private static Instalacao__c createInstallation(Id opportunityId, String status) {
        InstalacaoTriggerHandler.disableTrigger();
        Instalacao__c inst = new Instalacao__c(
            Name = 'Instalação Teste',
            Oportunidade__c = opportunityId,
            Status__c = status
        );
        insert inst;
        InstalacaoTriggerHandler.enableTrigger();
        return inst;
    }

    private static void createFinalReportTask(Id installationId) {
        Task t = new Task(
            Subject = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
            Status = TaskUtils.STATUS_CONCLUIDO,
            WhatId = installationId
        );
        insert t;
    }

    private static void createTemplateWithFiles() {
        ProposalCover__c template = new ProposalCover__c(
            Name = WorkDeliveryReportService.TEMPLATE_NAME,
            Template__c = 'WorkDeliveryReportPdf',
            IsActive__c = true
        );
        insert template;

        ContentVersion cover = new ContentVersion(
            Title = WorkDeliveryReportService.COVER_TITLE,
            PathOnClient = 'capa.png',
            VersionData = Blob.valueOf('COVER')
        );
        insert cover;
        cover = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cover.Id];

        ContentVersion back = new ContentVersion(
            Title = WorkDeliveryReportService.BACK_COVER_TITLE,
            PathOnClient = 'contra_capa.png',
            VersionData = Blob.valueOf('BACK')
        );
        insert back;
        back = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :back.Id];

        List<ContentDocumentLink> links = new List<ContentDocumentLink>{
            new ContentDocumentLink(
                ContentDocumentId = cover.ContentDocumentId,
                LinkedEntityId = template.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ),
            new ContentDocumentLink(
                ContentDocumentId = back.ContentDocumentId,
                LinkedEntityId = template.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            )
        };
        insert links;
    }

    private static List<String> loadRequiredDocs() {
        ActivityRequiredDocument__mdt cfg = [
            SELECT RequiredFiles__c
            FROM ActivityRequiredDocument__mdt
            WHERE ActivitySubject__c = :TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA
            LIMIT 1
        ];
        List<String> docs = new List<String>();
        for (String name : cfg.RequiredFiles__c.split(';')) {
            if (String.isBlank(name)) {
                continue;
            }
            docs.add(name.trim());
        }
        return docs;
    }

    private static void createExternalAttachments(Id installationId, List<String> docs, Integer skipIndex) {
        List<OpportunityAttachmentLink__c> links = new List<OpportunityAttachmentLink__c>();
        for (Integer i = 0; i < docs.size(); i++) {
            if (skipIndex != null && i == skipIndex) {
                continue;
            }
            links.add(new OpportunityAttachmentLink__c(
                Name = docs[i],
                ActivityName__c = TaskUtils.SUBJECT_RELATORIO_FINAL_DE_OBRA,
                SObjectId__c = String.valueOf(installationId),
                AttachmentDescription__c = docs[i],
                DocRequiredName__c = docs[i],
                AttachmentURL__c = 'https://gerenciadorblobhomolog.blob.core.windows.net/shared/ProposalExternalArchive/doc' + i + '.jpg'
            ));
        }
        insert links;
    }

    private class AzureBlobMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'image/png');
            res.setBodyAsBlob(Blob.valueOf('PNGDATA'));
            return res;
        }
    }
}
