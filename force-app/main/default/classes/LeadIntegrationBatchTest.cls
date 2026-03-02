/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 10-09-2025
 * @last modified by	 : Daniel Belini
 **/
@isTest
public class LeadIntegrationBatchTest {
  @isTest
  static void testBatchExecution() {
    Lead testLead3 = new Lead(
      FirstName = 'Test3',
      LastName = 'Lead',
      Company = 'Acme Corp',
      Email = 'test.lead@example.com',
      CPFCNPJ__c = '12345678901',
      Lb065_FaturaEnergia__c = 1000,
      Phone = '123456789',
      Lb065_ProdutoInteresse__c = 'Ezee Solar',
      Lb065_HistoricoLead__c = 'Histórico...',
      Lb065_Estado__c = 'MT',
      LeadSource = 'Nivello',
      Title = 'Sr.',
      Street = 'Rua A',
      City = 'Cidade B',
      Country = 'Brasil',
      InteresseEnergiaRenovavel__c = null,
      InteresseEnergiaSolar__c = null,
      TipoDeImovel__c = 'com telhado fibrocimento',
      CustoEnergiaMes__c = 'até R$ 300',
      ValorContaEnergia__c = 'Até R$ 200',
      Rating = 'Hot',
      Mensagem__c = 'Msg',
      Complemento__c = 'Comp',
      PostalCode = '12345-678',
      Status = 'Distribuído',
      RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByName()
        .get('Qualificação de Clientes')
        .getRecordTypeId()
    );
    insert testLead3;

    Test.startTest();
    LeadIntegrationBatch batch = new LeadIntegrationBatch();
    Database.executeBatch(batch, 1);
    Test.stopTest();

    // Reload lead and check integration flag
    Lead updatedLead = [
      SELECT Lab065_IntegracaoDistribuicaoLead__c
      FROM Lead
      WHERE Id = :testLead3.Id
      LIMIT 1
    ];
  }
}
