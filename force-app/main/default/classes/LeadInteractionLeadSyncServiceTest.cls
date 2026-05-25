/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 05-25-2026
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
      TipoImovel__c = 'Casa',
      Cidade__c = 'Porto Alegre do Norte',
      Estado__c = 'MT',
      ResumoInteracao__c = 'Resumo de teste',
      Telefone__c = '0MwU500000JnV4rKAF'
    );

    LeadTriggerHandler.disableTrigger();
    try {
      insert interaction;
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
        Lb065_PontuacaoFatura__c,
        Lb065_PontuacaoOrigem__c,
        Lb065_ProdutoInteresse__c,
        TipoDeImovel__c,
        Lab065_IntegracaoDistribuicaoLead__c,
        SDRAgent__c
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
    Assert.areEqual('até R$ 300 a R$ 500', updated.CustoEnergiaMes__c);
    Assert.areEqual('Entre R$ 200 e R$ 499', updated.ValorContaEnergia__c);
    Assert.areEqual(5, updated.Lb065_PontuacaoFatura__c);
    Assert.areEqual(6, updated.Lb065_PontuacaoOrigem__c);
    Assert.areEqual('Ezee Solar', updated.Lb065_ProdutoInteresse__c);
    Assert.areEqual('Casa', updated.TipoDeImovel__c);
    Assert.isFalse(updated.Lab065_IntegracaoDistribuicaoLead__c);
    Assert.isTrue(updated.SDRAgent__c);
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
        Lb065_FaturaEnergia__c,
        Lb065_PontuacaoFatura__c,
        Lb065_PontuacaoOrigem__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.areEqual('Novo', updated.FirstName);
    Assert.areEqual('Sobrenome', updated.LastName);
    Assert.areEqual('novo@email.com', updated.Email);
    Assert.areEqual('556481627918', updated.MobilePhone);
    Assert.areEqual('556481627918', updated.Phone);
    Assert.areEqual(Decimal.valueOf('1250.50'), updated.Lb065_FaturaEnergia__c);
    Assert.areEqual(15, updated.Lb065_PontuacaoFatura__c);
    Assert.areEqual(10, updated.Lb065_PontuacaoOrigem__c);
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
      insert interaction;
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
}
