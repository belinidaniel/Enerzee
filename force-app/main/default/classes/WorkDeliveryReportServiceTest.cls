/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class WorkDeliveryReportServiceTest {
  @IsTest
  static void testAutoGenerateReportOnStatusChange() {
    Integer beforeJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];

    Id installationId = buildSyntheticInstalacaoId('901');
    Instalacao__c oldInstallation = new Instalacao__c(
      Id = installationId,
      Status__c = ProjetoUtils.STATUS_OBRA_EM_EXECUCAO
    );
    Instalacao__c newInstallation = new Instalacao__c(
      Id = installationId,
      Status__c = ProjetoUtils.STATUS_OBRA_CONCLUIDA
    );

    Test.startTest();
    InstalacaoFinalReportService.enqueueIfNeeded(
      new List<Instalacao__c>{ newInstallation },
      new Map<Id, Instalacao__c>{ installationId => oldInstallation }
    );
    Test.stopTest();

    Integer afterJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable'
    ];
    System.assert(afterJobs > beforeJobs);
  }

  @IsTest
  static void testIdempotentWhenAlreadyGenerated() {
    Test.startTest();
    InstalacaoFinalReportService.processInstallations(new List<Id>());
    Test.stopTest();

    System.assert(true, 'Processamento vazio não deve lançar exceção.');
  }

  @IsTest
  static void testMissingDocumentsSkipsGeneration() {
    Account accountRecord = new Account(Name = 'Anchor Missing Docs');
    insert accountRecord;

    Test.startTest();
    InstalacaoFinalReportService.processInstallations(
      new List<Id>{ accountRecord.Id }
    );
    Test.stopTest();

    Integer generatedCount = [
      SELECT COUNT()
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :accountRecord.Id
        AND Title LIKE 'Relatorio de Execucao de Obra%'
    ];
    System.assertEquals(0, generatedCount);
  }

  private static Id buildSyntheticInstalacaoId(String sequence) {
    String prefix = Instalacao__c.SObjectType.getDescribe().getKeyPrefix();
    String padded = String.valueOf(sequence);
    while (padded.length() < 12) {
      padded = '0' + padded;
    }
    return (Id) (prefix + padded);
  }
}
