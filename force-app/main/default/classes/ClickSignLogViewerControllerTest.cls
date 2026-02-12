@IsTest
private class ClickSignLogViewerControllerTest {
    private static User createAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            Alias = 'adm',
            Email = 'admin_' + DateTime.now().getTime() + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'pt_BR',
            LocaleSidKey = 'pt_BR',
            TimeZoneSidKey = 'America/Sao_Paulo',
            Username = 'admin_' + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @IsTest
    static void shouldReturnLogsAndDetails() {
        Account acc = new Account(Name = 'Conta');
        insert acc;
        ClickSignLog__c log = new ClickSignLog__c(Name = 'Log', RelatedId__c = acc.Id, Status__c = '200');
        insert log;

        User admin = createAdminUser();
        System.runAs(admin) {
            System.assertEquals(true, ClickSignLogViewerController.isCurrentUserAdmin());
            List<ClickSignLog__c> logs = ClickSignLogViewerController.getLogsByClickSign(acc.Id, 10);
            System.assertEquals(1, logs.size());

            ClickSignLog__c detail = ClickSignLogViewerController.getLogDetail(log.Id);
            System.assertEquals(log.Id, detail.Id);
        }
    }
}
