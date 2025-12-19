/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-19-2025
 * @last modified by  : Daniel Belini
**/
@isTest
private class TaskCompletionServiceDocTest {
    @isTest
    static void completeWithoutRequiredDocs() {
        Task t = new Task(Subject = 'TESTE SEM CMDT', Status = 'Not Started');
        insert t;

        Test.startTest();
        TaskCompletionService.CompletionResult res = TaskCompletionService.completeWithComment(t.Id, 'ok', false, null);
        Test.stopTest();

        System.assert(res != null && res.success, 'Conclusão deve ocorrer sem CMDT configurado.');
    }

    @isTest
    static void normalizeNameHandlesAccents() {
        String norm = TaskCompletionService.normalizeName('MOBILIZAÇÃO/CONFERÊNCIA DE MATERIAIS');
        System.assertEquals('mobilizacao_conferencia_de_materiais', norm);
    }
}
