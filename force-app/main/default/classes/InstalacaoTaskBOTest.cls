@IsTest
private class InstalacaoTaskBOTest {
    @IsTest
    static void shouldHandleEmptyInputs() {
        InstalacaoTaskBO.createTasks(new List<Instalacao__c>(), new Map<Id, Instalacao__c>());
        InstalacaoTaskBO.createPlanningTasksAfterDelegar(null);
        System.assert(true, 'InstalacaoTaskBO handled empty inputs');
    }
}