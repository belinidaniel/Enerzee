@IsTest
private class InstallCompletionNotifyServiceTest {
  @IsTest
  static void shouldSendEmailOnlyOnTransitionToCompleted() {
    InstallCompletionNotifyService.setTestConfig(
      true,
      'Obra concluída;Obra concluída - Aguardando troca de medidor',
      'notify1@test.com;notify2@test.com'
    );

    Instalacao__c installation = createInstallation('Planejamento de Obra');
    Instalacao__c oldInstallation = installation.clone(
      false,
      true,
      false,
      false
    );
    oldInstallation.Status__c = 'Planejamento de Obra';

    InstalacaoTriggerHandler.disableTrigger();
    installation.Status__c = 'Obra concluída';
    update installation;
    InstalacaoTriggerHandler.enableTrigger();

    Test.startTest();
    InstallCompletionNotifyService.notifyOnCompletion(
      new List<Instalacao__c>{ installation },
      new Map<Id, Instalacao__c>{ installation.Id => oldInstallation }
    );
    System.assertEquals(
      1,
      Limits.getEmailInvocations(),
      'Deve enviar e-mail na transição para concluído.'
    );
    Test.stopTest();

    InstallCompletionNotifyService.clearTestConfig();
  }

  @IsTest
  static void shouldNotResendWhenStatusRemainsCompleted() {
    InstallCompletionNotifyService.setTestConfig(
      true,
      'Obra concluída',
      'notify@test.com'
    );

    Instalacao__c installation = createInstallation('Obra concluída');
    Instalacao__c oldInstallation = installation.clone(
      false,
      true,
      false,
      false
    );
    oldInstallation.Status__c = 'Obra concluída';

    InstalacaoTriggerHandler.disableTrigger();
    installation.Name = installation.Name + ' Atualizada';
    update installation;
    InstalacaoTriggerHandler.enableTrigger();

    Test.startTest();
    InstallCompletionNotifyService.notifyOnCompletion(
      new List<Instalacao__c>{ installation },
      new Map<Id, Instalacao__c>{ installation.Id => oldInstallation }
    );
    System.assertEquals(
      0,
      Limits.getEmailInvocations(),
      'Não deve reenviar e-mail sem transição de status.'
    );
    Test.stopTest();

    InstallCompletionNotifyService.clearTestConfig();
  }

  private static Instalacao__c createInstallation(String status) {
    Account account = new Account(Name = 'Cliente Notificacao');
    insert account;

    Opportunity opportunity = new Opportunity(
      Name = 'Opp Notificacao',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10),
      AccountId = account.Id,
      NumeroInstalacao__c = 'INST-001',
      IdVirtualOffice__c = 'VO-TEST-001'
    );
    insert opportunity;

    ViabilityStudy__c viability = new ViabilityStudy__c(
      Opportunity__c = opportunity.Id,
      TypeWorkProjectFeasibility__c = 'UFV Micro'
    );
    insert viability;

    Projeto__c project = new Projeto__c(
      Name = 'Projeto Notificacao',
      Status__c = ProjetoUtils.STATUS_PLANEJAMENTO,
      Oportunidade__c = opportunity.Id,
      Viabilidade__c = viability.Id,
      Conta__c = account.Id,
      TipoObra__c = 'UFVMicro',
      RecordTypeId = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
        .get('UFVMicro')
        .getRecordTypeId()
    );
    insert project;

    InstalacaoTriggerHandler.disableTrigger();
    Instalacao__c installation = new Instalacao__c(
      Name = 'Instalação Notificação',
      Status__c = status,
      Projeto__c = project.Id,
      Oportunidade__c = opportunity.Id,
      ClienteConta__c = account.Id
    );
    insert installation;
    InstalacaoTriggerHandler.enableTrigger();
    return installation;
  }
}
