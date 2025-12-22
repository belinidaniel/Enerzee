/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
private class OpportunityBOAdditionalTest {

    private static User createCloserUser() {
        Id profileId = [SELECT Id FROM Profile LIMIT 1].Id;
        User u = new User(
            Alias = 'wagner',
            Email = 'wagner.sampaio@enerzee.com.br.test',
            Username = 'wagner.sampaio@enerzee.com.br.test',
            LastName = 'Closer',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId
        );
        insert u;
        return u;
    }

    @IsTest
    static void shouldCloseFollowUpCallTasks() {
        User closer = createCloserUser();
        Account acc = new Account(Name = 'Opp Acc');
        insert acc;

        Opportunity oldOpp = new Opportunity(
            Name = 'Opp FollowUp',
            IdVirtualOffice__c = 'vo-followup',
            StageName = OpportunityUtils.STATUS_PROPOSTA_ENVIADA,
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert oldOpp;
        Opportunity newOpp = oldOpp.clone(false, true, true, true);
        newOpp.StageName = OpportunityUtils.STATUS_NEGOCIACAO;

        Task t = new Task(
            WhatId = oldOpp.Id,
            OwnerId = closer.Id,
            Status = 'Open',
            Subject = 'Ligação de follow-up - teste'
        );
        insert t;

        Test.startTest();
        OpportunityBO.checksAndClosesTaskFollowUpCall(
            new List<Opportunity>{ newOpp },
            new Map<Id, Opportunity>{ newOpp.Id => oldOpp }
        );
        Test.stopTest();

        Task updated = [SELECT Status, MetodoDeFollowup__c FROM Task WHERE Id = :t.Id];
    }

}
