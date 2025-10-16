@isTest
public class ConsultorTriggerTest {
    
    @TestSetup
    static void makeData(){
        Consultor__c consultor1 = (Consultor__c) TestFactory.createSObject(new Consultor__c(
            NumeroIdentificacao__c = null
        ), true);
        Consultor__c consultor2 = (Consultor__c) TestFactory.createSObject(new Consultor__c(
            CPF__c                 = '223.456.789-01',
            CNPJ__c                = '22.345.678/9012-34',
            IdVirtualOffice__c     = 'sandkasdj9238uealsk',
            NumeroIdentificacao__c = null
        ), true);
    }

    @isTest
    static void assignCPFCNPJToIdentificationNumberTest(){
        Consultor__c consultor = [
            SELECT  Id, SeCPFouCNPJ__c, NumeroIdentificacao__c
            FROM    Consultor__c
            LIMIT   1
        ];
        System.assertEquals(consultor.SeCPFouCNPJ__c, consultor.NumeroIdentificacao__c);
    }

    @isTest
    static void coverageOtherTriggerMethods(){
        Consultor__c consultor = [
            SELECT  Id, Name
            FROM    Consultor__c
            LIMIT   1
        ];
        
        consultor.Name = 'Teste 2';
        update consultor;

        delete consultor;

        ConsultorTriggerHandler.disableTrigger();
        System.assert(!ConsultorTriggerHandler.isTriggerEnabled());
        
        ConsultorTriggerHandler.enableTrigger();
        System.assert(ConsultorTriggerHandler.isTriggerEnabled());
    }
}