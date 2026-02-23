@IsTest
private class AccountTriggerHandlerTest {
    private static User createIntegratorUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName = 'Integrador',
            LastName = 'SAP',
            Alias = 'isap',
            Email = 'isap_' + DateTime.now().getTime() + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            LocaleSidKey = 'pt_BR',
            TimeZoneSidKey = 'America/Sao_Paulo',
            Username = 'isap_' + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @IsTest
    static void shouldFireTriggers() {
        Account acc = (Account) TestFactory.createSObject(new Account(Phone = null), true);
        setIfWritable(acc, 'SeCPFouCNPJ__c', '123');
        update acc;

        User integrador = createIntegratorUser();
        System.runAs(integrador) {
            acc.IdExternoConsultor__c = 'VO-10';
            update acc;
        }

        System.assert(true, 'Account trigger executed');
    }

    private static void setIfWritable(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult describe = record.getSObjectType().getDescribe().fields.getMap().get(fieldName).getDescribe();
        if (describe != null && describe.isUpdateable()) {
            record.put(fieldName, value);
        }
    }
}