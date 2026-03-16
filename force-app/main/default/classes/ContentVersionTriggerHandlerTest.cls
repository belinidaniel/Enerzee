/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class ContentVersionTriggerHandlerTest {
  @IsTest
  static void shouldFillIsProposal() {
    ContentVersionTriggerHandler.enableTrigger();
    ContentVersion cv = new ContentVersion(
      Title = 'Proposta Teste',
      PathOnClient = 'proposta.pdf',
      VersionData = Blob.valueOf('teste')
    );
    insert cv;

    ContentVersion inserted = [
      SELECT Id, IsProposal__c
      FROM ContentVersion
      WHERE Id = :cv.Id
    ];
    System.assertEquals(true, inserted.IsProposal__c);
  }

  @IsTest
  static void shouldSkipTriggerWhenDisabledAndEnableAgain() {
    ContentVersionTriggerHandler.disableTrigger();
    System.assertEquals(false, ContentVersionTriggerHandler.isTriggerEnabled());

    ContentVersion disabledCv = new ContentVersion(
      Title = 'Proposta Desabilitada',
      PathOnClient = 'proposta-disabled.pdf',
      VersionData = Blob.valueOf('disabled')
    );
    insert disabledCv;

    ContentVersion insertedDisabled = [
      SELECT Id, IsProposal__c
      FROM ContentVersion
      WHERE Id = :disabledCv.Id
    ];
    System.assertEquals(
      false,
      insertedDisabled.IsProposal__c,
      'Com a trigger desligada, a flag não deve ser preenchida.'
    );

    ContentVersionTriggerHandler.enableTrigger();
    System.assertEquals(true, ContentVersionTriggerHandler.isTriggerEnabled());
  }

  @IsTest
  static void shouldExecuteOperationsWithoutTriggerContext() {
    ContentVersion proposalVersion = new ContentVersion(
      Title = 'P-2026',
      PathOnClient = 'p-2026.pdf',
      VersionData = Blob.valueOf('proposal')
    );

    ContentVersionTriggerHandler handler = (ContentVersionTriggerHandler) JSON.deserialize(
      '{}',
      ContentVersionTriggerHandler.class
    );

    handler.operation = System.TriggerOperation.BEFORE_INSERT;
    handler.newRecordList = new List<SObject>{ proposalVersion };
    handler.execute();
    System.assertEquals(
      true,
      proposalVersion.IsProposal__c,
      'O execute deve delegar para beforeInsert e preencher a flag.'
    );

    handler.operation = System.TriggerOperation.AFTER_INSERT;
    handler.execute();
    handler.operation = System.TriggerOperation.BEFORE_UPDATE;
    handler.execute();
    handler.operation = System.TriggerOperation.AFTER_UPDATE;
    handler.execute();
    handler.operation = System.TriggerOperation.BEFORE_DELETE;
    handler.execute();
    handler.operation = System.TriggerOperation.AFTER_DELETE;
    handler.execute();

    ContentVersion nonProposalVersion = new ContentVersion(
      Title = 'Arquivo Complementar',
      PathOnClient = 'complementar.pdf',
      VersionData = Blob.valueOf('non-proposal')
    );
    handler.newRecordList = new List<SObject>{ nonProposalVersion };
    handler.operation = System.TriggerOperation.BEFORE_INSERT;
    handler.execute();
    System.assertEquals(
      false,
      nonProposalVersion.IsProposal__c,
      'Arquivos sem padrão de proposta devem permanecer sem flag.'
    );
  }
}
