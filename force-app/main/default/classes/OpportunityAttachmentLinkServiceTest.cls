@isTest
private class OpportunityAttachmentLinkServiceTest {

    @isTest
    static void upsertAttachmentInsertsRecord() {
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        OpportunityAttachmentLinkService.AttachmentInput input =
            new OpportunityAttachmentLinkService.AttachmentInput();
        input.opportunityId = opp.Id;
        input.attachmentUrl = 'https://example.com/proposal.pdf';
        input.description = 'Teste';
        input.type = 'Proposal';

        Test.startTest();
        OpportunityAttachmentLinkService.upsertAttachment(input);
        Test.stopTest();

        OpportunityAttachmentLink__c saved = [
            SELECT OpportunityId__c, AttachmentURL__c, Type__c
            FROM OpportunityAttachmentLink__c
            LIMIT 1
        ];
        System.assertEquals(opp.Id, saved.OpportunityId__c);
        System.assertEquals('https://example.com/proposal.pdf', saved.AttachmentURL__c);
        System.assertEquals('Proposal', saved.Type__c);
    }

    @isTest
    static void upsertAttachmentUsesExternalId() {
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(), true);

        OpportunityAttachmentLinkService.AttachmentInput input =
            new OpportunityAttachmentLinkService.AttachmentInput();
        input.opportunityId = opp.Id;
        input.attachmentUrl = 'https://example.com/proposal.pdf';
        input.description = 'Primeiro';
        input.externalId = 'ext-id';
        input.type = 'Proposal';

        OpportunityAttachmentLinkService.upsertAttachment(input);

        OpportunityAttachmentLinkService.AttachmentInput inputUpdate =
            new OpportunityAttachmentLinkService.AttachmentInput();
        inputUpdate.opportunityId = opp.Id;
        inputUpdate.attachmentUrl = 'https://example.com/proposal-v2.pdf';
        inputUpdate.description = 'Atualizado';
        inputUpdate.externalId = 'ext-id';
        inputUpdate.type = 'Proposal';

        Test.startTest();
        OpportunityAttachmentLinkService.upsertAttachment(inputUpdate);
        Test.stopTest();

        OpportunityAttachmentLink__c saved = [
            SELECT AttachmentURL__c, AttachmentDescription__c
            FROM OpportunityAttachmentLink__c
            WHERE ExternalId__c = 'ext-id'
            LIMIT 1
        ];
        System.assertEquals('https://example.com/proposal-v2.pdf', saved.AttachmentURL__c);
        System.assertEquals('Atualizado', saved.AttachmentDescription__c);
    }
}