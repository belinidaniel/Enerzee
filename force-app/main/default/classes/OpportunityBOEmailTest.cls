/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
private class OpportunityBOEmailTest {

    private static User createUserWithEmail(String email) {
        Id profileId = [SELECT Id FROM Profile LIMIT 1].Id;
        User u = new User(
            Alias = 'u' + String.valueOf(Crypto.getRandomInteger()).substring(0, 3),
            Email = email,
            Username = email,
            LastName = 'User',
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
    static void shouldAppendAutomationNoteVariants() {
        // blank note or invalid max length keeps current
        System.assertEquals('current', OpportunityBO.appendAutomationNote('current', '', 10));
        System.assertEquals('current', OpportunityBO.appendAutomationNote('current', 'note', 0));

        // when current is empty, returns note (respecting max length)
        System.assertEquals('nota', OpportunityBO.appendAutomationNote('', 'nota', 10));
        System.assertEquals('no', OpportunityBO.appendAutomationNote('', 'nota', 2));

        // avoid duplicate
        System.assertEquals('valor | nota', OpportunityBO.appendAutomationNote('valor', 'nota', 50));
        System.assertEquals('valor | nota', OpportunityBO.appendAutomationNote('valor | nota', 'nota', 50));
    }

    @IsTest
    static void shouldHandleClosedLostEmailWithoutSendingInTest() {
        User u = createUserWithEmail('user22@exam22ple.com');
        Account acc = new Account(Name = 'Acc Email');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp Email',
            StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO,
            CloseDate = Date.today(),
            AccountId = acc.Id,
            IdVirtualOffice__c = 'vo-email'
        );
        insert opp;

        Test.startTest();
        OpportunityBO.sendClosedLostAutomationEmail(
            new List<Opportunity>{opp},
            new Set<Id>{u.Id},
            'Nota de automação'
        );
        Test.stopTest();

    }
}
