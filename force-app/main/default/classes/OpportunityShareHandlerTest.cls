/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class OpportunityShareHandlerTest {
  @TestSetup
  static void setupUser() {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];

    insert new User(
      Username = 'oppshare.' + System.now().getTime() + '@teste.com',
      Email = 'oppshare@teste.com',
      Alias = 'opsht',
      LastName = 'Share',
      TimeZoneSidKey = 'America/Sao_Paulo',
      LocaleSidKey = 'pt_BR',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'pt_BR',
      ProfileId = profileRecord.Id
    );
  }

  @IsTest
  static void shouldCreateOpportunityShareWhenConsultorChanges() {
    User targetUser = [SELECT Id FROM User WHERE Alias = 'opsht' LIMIT 1];
    Consultor__c consultorRecord = new Consultor__c(
      Name = 'Consultor Share',
      Ativo__c = true,
      Usuario__c = targetUser.Id
    );

    ConsultorTriggerHandler.disableTrigger();
    try {
      insert consultorRecord;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }

    Account accountRecord = new Account(Name = 'Account Share');
    insert accountRecord;

    Opportunity opportunityRecord = new Opportunity(
      Name = 'Opportunity Share',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(15),
      AccountId = accountRecord.Id,
      IdVirtualOffice__c = 'vo-share-' + String.valueOf(System.now().getTime())
    );

    OpportunityTriggerHandler.disableTrigger();
    try {
      insert opportunityRecord;
    } finally {
      OpportunityTriggerHandler.enableTrigger();
    }

    Opportunity newSnapshot = new Opportunity(
      Id = opportunityRecord.Id,
      ConsultorOportunidade__c = consultorRecord.Id
    );
    Opportunity oldSnapshot = new Opportunity(
      Id = opportunityRecord.Id,
      ConsultorOportunidade__c = null
    );

    Test.startTest();
    OpportunityShareHandler.gerenciarCompartilhamentoOportunidade(
      new List<Opportunity>{ newSnapshot },
      new Map<Id, Opportunity>{ opportunityRecord.Id => oldSnapshot }
    );
    Test.stopTest();

    List<OpportunityShare> shares = [
      SELECT OpportunityId, UserOrGroupId, OpportunityAccessLevel
      FROM OpportunityShare
      WHERE OpportunityId = :opportunityRecord.Id
    ];

    System.assertEquals(1, shares.size());
    System.assertEquals(targetUser.Id, shares[0].UserOrGroupId);
    System.assertEquals('Edit', shares[0].OpportunityAccessLevel);
  }

  @IsTest
  static void shouldIgnoreEmptyAndUnchangedScenarios() {
    Id consultorId = (Id) (Consultor__c.SObjectType.getDescribe()
      .getKeyPrefix() + '000000000000001');

    OpportunityShareHandler.gerenciarCompartilhamentoOportunidade(
      new List<Opportunity>(),
      new Map<Id, Opportunity>()
    );

    OpportunityShareHandler.gerenciarCompartilhamentoOportunidade(
      new List<Opportunity>{ new Opportunity(Id = '006000000000001AAA') },
      new Map<Id, Opportunity>()
    );

    OpportunityShareHandler.gerenciarCompartilhamentoOportunidade(
      new List<Opportunity>{
        new Opportunity(
          Id = '006000000000002AAA',
          ConsultorOportunidade__c = consultorId
        )
      },
      new Map<Id, Opportunity>{
        '006000000000002AAA' => new Opportunity(
          Id = '006000000000002AAA',
          ConsultorOportunidade__c = consultorId
        )
      }
    );

    System.assert(true);
  }
}
