@IsTest
private class KitInstalacaoBOTest {
    @IsTest
    static void shouldPopulateAndCalculate() {
        KitInstalacaoTriggerHandler.disableTrigger();
        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id,
            Name = 'Opp Kit',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            IdVirtualOffice__c = 'VO-KIT'
        ), true);

        Kit_Instalacao__c kit = (Kit_Instalacao__c) TestFactory.createSObject(
            new Kit_Instalacao__c(Nome_da_Oportunidade__c = opp.Id),
            true
        );

        KitInstalacaoBO.populateKitFields(new List<Kit_Instalacao__c>{ kit });
        System.assertEquals('Unidade', kit.UnidadeMedidaLocacao__c);

        KitInstalacaoBO.calculateValueKit(new List<Kit_Instalacao__c>{ kit });
        KitInstalacaoBO.sendKitRecordsToSAP(new List<Kit_Instalacao__c>());
        KitInstalacaoTriggerHandler.enableTrigger();
    }
}