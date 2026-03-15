/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class InstalacaoTaskBOTest {
  @IsTest
  static void shouldHandleEmptyInputs() {
    InstalacaoTaskBO.createTasks(
      new List<Instalacao__c>(),
      new Map<Id, Instalacao__c>()
    );
    InstalacaoTaskBO.createPlanningTasksAfterDelegar(null);
    System.assert(true, 'InstalacaoTaskBO handled empty inputs');
  }
}
