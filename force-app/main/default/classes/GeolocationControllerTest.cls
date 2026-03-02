@isTest
public class GeolocationControllerTest {
  @isTest
  static void saveGeolocationTest() {
    Test.startTest();
    ProposalCover__c ProposalCover = (ProposalCover__c) TestFactory.createSObject(
      new ProposalCover__c(),
      true
    );
    Parceiro__c parceiro = (Parceiro__c) TestFactory.createSObject(
      new Parceiro__c(CapaProposta__c = ProposalCover.id, Produto__c = 'Solar'),
      true
    );

    Account account = (Account) TestFactory.createSObject(new Account(), true);
    Consultor__c consultor = (Consultor__c) TestFactory.createSObject(
      new Consultor__c(),
      true
    );
    Opportunity opp = (Opportunity) TestFactory.createSObject(
      new Opportunity(
        AccountId = account.Id,
        ConsultorOportunidade__c = consultor.Id,
        Parceiro__c = parceiro.id,
        PotenciaPicoSistema__c = 12
      ),
      true
    );

    Id recordId = opp.Id;

    Decimal latitude = -15.6131249;
    Decimal longitude = -56.0853574;
    String telhado = 'Ao Solo';

    GeolocationController.saveGeolocation(
      recordId,
      latitude,
      longitude,
      telhado
    );

    Opportunity updatedOpp = [
      SELECT
        LocalizacaoFixa__Latitude__s,
        LocalizacaoFixa__Longitude__s,
        TipoTelhadoEstrutura__c
      FROM Opportunity
      WHERE Id = :recordId
    ];

    System.assertEquals(
      latitude,
      updatedOpp.LocalizacaoFixa__Latitude__s,
      'Latitude não foi atualizada corretamente'
    );
    System.assertEquals(
      longitude,
      updatedOpp.LocalizacaoFixa__Longitude__s,
      'Longitude não foi atualizada corretamente'
    );
    System.assertEquals(
      telhado,
      updatedOpp.TipoTelhadoEstrutura__c,
      'telhado não foi atualizado corretamente'
    );
    Test.stopTest();
  }
}
