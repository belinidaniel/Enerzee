/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Daniel Belini
**/
@IsTest
private class TaskStateServiceTest {

    @IsTest
    static void shouldReturnState() {
        TaskTriggerHandler.disableTrigger();
        Task t = new Task(Subject = 'Estado da tarefa', Status = 'Not Started');
        insert t;

        Test.startTest();
        TaskStateService.TaskState state = TaskStateService.getState(t.Id);
        Test.stopTest();

    }

    @IsTest
    static void shouldRequireId() {
        try {
            TaskStateService.getState(null);
        } catch (AuraHandledException e) {
        }
    }
}
