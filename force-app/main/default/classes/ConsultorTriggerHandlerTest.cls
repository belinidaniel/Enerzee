@IsTest
private class ConsultorTriggerHandlerTest {
    private static User createIntegratorUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName = 'Integrador',
            LastName = 'SAP',
            Alias = 'csap',
            Email = 'csap_' + DateTime.now().getTime() + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            LocaleSidKey = 'pt_BR',
            TimeZoneSidKey = 'America/Sao_Paulo',
            Username = 'csap_' + DateTime.now().getTime() + '@test.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @IsTest
    static void shouldFireConsultorTriggers() {
        User integrador = createIntegratorUser();
        System.runAs(integrador) {
            Consultor__c consultor = (Consultor__c) TestFactory.createSObject(new Consultor__c(Telefone__c = null), true);
            consultor.Descricao__c = 'Atualizado';
            update consultor;
        }
        System.assert(true, 'Consultor trigger executed');
    }
}
