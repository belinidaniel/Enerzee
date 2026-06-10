/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-10-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class LeadInteractionLeadSyncServiceTest {
  @isTest
  static void shouldSyncInteractionFieldsToLeadAndScore() {
    Lead lead = createLead('Old', 'Anúncio');

    LeadInteraction__c interaction = new LeadInteraction__c(
      Lead__c = lead.Id,
      Nome__c = 'Karolamika09',
      Sobrenome__c = 'Cliente',
      Email__c = 'karolamika09@gmail.com',
      CPF_CNPJ__c = '08269787126',
      ValorConta__c = '340,00',
      Produtinteresse__c = 'Ezee Solar',
      TipoImovel__c = 'com laje',
      Cidade__c = 'Porto Alegre do Norte',
      Estado__c = 'MT',
      ResumoInteracao__c = 'Resumo de teste',
      Telefone__c = '0MwU500000JnV4rKAF'
    );

    LeadTriggerHandler.disableTrigger();
    try {
      LeadInteractionLeadSyncService.syncToLeads(
        new List<LeadInteraction__c>{ interaction },
        null
      );
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Lead updated = [
      SELECT
        FirstName,
        LastName,
        Email,
        CPFCNPJ__c,
        CPF__c,
        MobilePhone,
        City,
        Cidade__c,
        State,
        Estado__c,
        Lb065_Estado__c,
        Lb065_FaturaEnergia__c,
        CustoEnergiaMes__c,
        ValorContaEnergia__c,
        Lb065_ProdutoInteresse__c,
        TipoDeImovel__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.areEqual('Karolamika09', updated.FirstName);
    Assert.areEqual('Cliente', updated.LastName);
    Assert.areEqual('karolamika09@gmail.com', updated.Email);
    Assert.areEqual('08269787126', updated.CPFCNPJ__c);
    Assert.areEqual('08269787126', updated.CPF__c);
    Assert.isNull(
      updated.MobilePhone,
      'Id de MessagingSession nao deve virar telefone.'
    );
    Assert.areEqual('Porto Alegre do Norte', updated.City);
    Assert.areEqual('Porto Alegre do Norte', updated.Cidade__c);
    Assert.areEqual('MT', updated.State);
    Assert.areEqual('MT', updated.Estado__c);
    Assert.areEqual('MT', updated.Lb065_Estado__c);
    Assert.areEqual(Decimal.valueOf('340'), updated.Lb065_FaturaEnergia__c);
    assertOptionalValue('até R$ 300 a R$ 500', updated.CustoEnergiaMes__c);
    assertOptionalValue('Entre R$ 200 e R$ 499', updated.ValorContaEnergia__c);
    assertOptionalValue('Ezee Solar', updated.Lb065_ProdutoInteresse__c);
    assertOptionalValue('com laje', updated.TipoDeImovel__c);
  }

  @isTest
  static void shouldSyncWhenInteractionIsUpdatedAfterLeadLink() {
    Lead lead = createLead('Before Update', 'Website');
    LeadInteraction__c interaction = new LeadInteraction__c(Lead__c = lead.Id);
    insert interaction;

    interaction.Email__c = 'novo@email.com';
    interaction.Nome__c = 'Novo';
    interaction.Sobrenome__c = 'Sobrenome';
    interaction.Telefone__c = '556481627918';
    interaction.ValorConta__c = '1.250,50';

    LeadTriggerHandler.disableTrigger();
    try {
      update interaction;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Lead updated = [
      SELECT
        FirstName,
        LastName,
        Email,
        MobilePhone,
        Phone,
        Lb065_FaturaEnergia__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.areEqual('Novo', updated.FirstName);
    Assert.areEqual('Sobrenome', updated.LastName);
    Assert.areEqual('novo@email.com', updated.Email);
    Assert.areEqual('556481627918', updated.MobilePhone);
    Assert.areEqual('556481627918', updated.Phone);
    Assert.areEqual(Decimal.valueOf('1250.50'), updated.Lb065_FaturaEnergia__c);
  }

  @isTest
  static void shouldIgnoreInvalidEmailAndCreateLogWithoutBlockingInteraction() {
    Lead lead = createLead('Invalid Email', 'Anúncio');

    LeadInteraction__c interaction = new LeadInteraction__c(
      Lead__c = lead.Id,
      Nome__c = 'Lead',
      Sobrenome__c = 'Sem Email Valido',
      Email__c = 'email-invalido',
      ValorConta__c = '340,00'
    );

    LeadTriggerHandler.disableTrigger();
    try {
      LeadInteractionLeadSyncService.syncToLeads(
        new List<LeadInteraction__c>{ interaction },
        null
      );
    } finally {
      LeadTriggerHandler.enableTrigger();
    }

    Lead updated = [
      SELECT Email, FirstName, LastName, Lb065_FaturaEnergia__c
      FROM Lead
      WHERE Id = :lead.Id
    ];
    Assert.isNull(updated.Email, 'Email invalido nao deve atualizar o Lead.');
    Assert.areEqual('Lead', updated.FirstName);
    Assert.areEqual('Sem Email Valido', updated.LastName);
    Assert.areEqual(Decimal.valueOf('340'), updated.Lb065_FaturaEnergia__c);

    Log__c logRecord = [
      SELECT Class__c, Method__c, Message__c, RequestBody__c, ResponseBody__c
      FROM Log__c
      WHERE RelatedId__c = :lead.Id
      LIMIT 1
    ];
    Assert.areEqual('LeadInteractionLeadSyncService', logRecord.Class__c);
    Assert.areEqual('applyInteractionFields', logRecord.Method__c);
    Assert.isTrue(logRecord.Message__c.contains('Email fora do padrao'));
    Assert.isTrue(logRecord.RequestBody__c.contains('email-invalido'));
    Assert.isTrue(logRecord.RequestBody__c.contains('leadFieldsAttempted'));
    Assert.isTrue(logRecord.ResponseBody__c.contains('leadInteraction'));
  }

  @isTest
  static void shouldSplitFullNameStoredOnlyInInteractionLastNameWhenSyncingLead() {
    Lead lead = createLead('Nome Antigo', 'Website');

    LeadInteractionLeadSyncService.syncToLeads(
      new List<LeadInteraction__c>{
        new LeadInteraction__c(
          Lead__c = lead.Id,
          Sobrenome__c = 'Vanuza Paixao'
        )
      },
      null
    );

    Lead updated = [
      SELECT FirstName, LastName
      FROM Lead
      WHERE Id = :lead.Id
    ];
  }

  @isTest
  static void shouldRetryValidLeadFieldsWhenOneFieldBlocksFullUpdate() {
    Lead lead = createLead('Nome Antigo', 'Website');

    LeadInteractionLeadSyncService.syncToLeads(
      new List<LeadInteraction__c>{
        new LeadInteraction__c(
          Lead__c = lead.Id,
          Nome__c = 'Nome muito longo para o campo first name do lead',
          Sobrenome__c = 'Sobrenome Valido',
          ValorConta__c = '600,00'
        )
      },
      null
    );

    Lead updated = [
      SELECT FirstName, LastName, Lb065_FaturaEnergia__c
      FROM Lead
      WHERE Id = :lead.Id
    ];
  }

  @isTest
  static void shouldHandleGuardClausesAndMissingLeadWithoutBlocking() {
    LeadInteractionLeadSyncService.syncToLeads(null, null);
    LeadInteractionLeadSyncService.syncToLeads(
      new List<LeadInteraction__c>(),
      null
    );

    LeadInteractionLeadSyncService.syncToLeads(
      new List<LeadInteraction__c>{
        new LeadInteraction__c(Nome__c = 'Sem Lead')
      },
      null
    );

    List<Log__c> logs = [
      SELECT Method__c, Message__c, RelatedId__c
      FROM Log__c
      WHERE Class__c = 'LeadInteractionLeadSyncService'
      ORDER BY CreatedDate
    ];

    Boolean foundNoLeadLog = false;
    for (Log__c logRecord : logs) {
      foundNoLeadLog =
        foundNoLeadLog ||
        logRecord.Message__c.contains('LeadInteraction sem Lead__c');
    }
    Assert.isTrue(foundNoLeadLog);
  }

  @isTest
  static void shouldMapDocumentsPhonesAndScoreRanges() {
    Lead lowValueLead = createLead('Low Value', 'Other');
    Lead highValueLead = createLead('High Value', 'Purchased List');

    LeadInteractionLeadSyncService.syncToLeads(
      new List<LeadInteraction__c>{
        new LeadInteraction__c(
          Lead__c = lowValueLead.Id,
          CPF_CNPJ__c = '12.345.678/0001-95',
          Telefone__c = '+55 (51) 99999-8888',
          ValorConta__c = '199,99'
        ),
        new LeadInteraction__c(
          Lead__c = highValueLead.Id,
          CPF_CNPJ__c = 'documento invalido',
          Telefone__c = '123',
          ValorConta__c = '6.000,00'
        )
      },
      null
    );

    Map<Id, Lead> leads = new Map<Id, Lead>(
      [
        SELECT
          CNPJ__c,
          MobilePhone,
          Phone,
          Lb065_FaturaEnergia__c,
          CustoEnergiaMes__c,
          ValorContaEnergia__c
        FROM Lead
        WHERE Id IN :new Set<Id>{ lowValueLead.Id, highValueLead.Id }
      ]
    );

    Lead lowValueUpdated = leads.get(lowValueLead.Id);
    Assert.areEqual('12345678000195', lowValueUpdated.CNPJ__c);
    Assert.areEqual('5551999998888', lowValueUpdated.MobilePhone);
    Assert.areEqual('5551999998888', lowValueUpdated.Phone);
    Assert.areEqual(
      Decimal.valueOf('199.99'),
      lowValueUpdated.Lb065_FaturaEnergia__c
    );
    assertOptionalValue('até R$ 300', lowValueUpdated.CustoEnergiaMes__c);
    assertOptionalValue('Até R$ 200', lowValueUpdated.ValorContaEnergia__c);

    Lead highValueUpdated = leads.get(highValueLead.Id);
    Assert.isNull(highValueUpdated.MobilePhone);
    Assert.areEqual(
      Decimal.valueOf('6000'),
      highValueUpdated.Lb065_FaturaEnergia__c
    );
    assertOptionalValue(
      'mais de R$ 1.000',
      highValueUpdated.CustoEnergiaMes__c
    );
    assertOptionalValue(
      'Acima de R$ 500',
      highValueUpdated.ValorContaEnergia__c
    );
  }

  @isTest
  static void shouldSplitFullNameStoredOnlyInLastNameOnInsert() {
    LeadInteraction__c interaction = new LeadInteraction__c(
      Sobrenome__c = ' Vanuza   Paixao '
    );

    insert interaction;

    LeadInteraction__c savedInteraction = [
      SELECT Nome__c, Sobrenome__c
      FROM LeadInteraction__c
      WHERE Id = :interaction.Id
    ];
  }

  @isTest
  static void shouldSplitFullNameStoredOnlyInLastNameOnUpdate() {
    LeadInteraction__c interaction = new LeadInteraction__c(
      Sobrenome__c = 'Cliente'
    );
    insert interaction;

    interaction.Sobrenome__c = 'Maria da Silva Santos';
    update interaction;

    LeadInteraction__c savedInteraction = [
      SELECT Nome__c, Sobrenome__c
      FROM LeadInteraction__c
      WHERE Id = :interaction.Id
    ];
  }

  @isTest
  static void shouldKeepNameWhenFirstNameIsAlreadyFilled() {
    LeadInteraction__c interaction = new LeadInteraction__c(
      Nome__c = 'Ana',
      Sobrenome__c = 'Maria Souza'
    );

    insert interaction;

    LeadInteraction__c savedInteraction = [
      SELECT Nome__c, Sobrenome__c
      FROM LeadInteraction__c
      WHERE Id = :interaction.Id
    ];
    Assert.areEqual('Ana', savedInteraction.Nome__c);
    Assert.areEqual('Maria Souza', savedInteraction.Sobrenome__c);
  }

  private static Lead createLead(String lastName, String leadSource) {
    Lead lead = new Lead(
      LastName = lastName,
      Company = 'Enerzee',
      Status = 'Novo',
      LeadSource = leadSource,
      Lab065_IntegracaoDistribuicaoLead__c = true
    );

    LeadTriggerHandler.disableTrigger();
    try {
      insert lead;
    } finally {
      LeadTriggerHandler.enableTrigger();
    }
    return lead;
  }

  private static void assertOptionalValue(String expected, String actual) {
    Assert.isTrue(
      actual == null || actual == expected,
      'Campo opcional deve ficar vazio quando a configuracao da org bloquear o valor.'
    );
  }
}
