/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class TaskDeadlineNotificationBatchTest {
  @IsTest
  static void shouldSkipWhenClosed() {
    Task t = new Task(
      Subject = 'Fechada',
      Status = TaskUtils.STATUS_CONCLUIDO,
      ActivityDate = Date.today()
    );
    insert t;

    Test.setCreatedDate(t.Id, System.now().addDays(-1));
    Test.startTest();
    Database.executeBatch(new TaskDeadlineNotificationBatch(), 1);
    Test.stopTest();

    Task reloaded = [SELECT Id, Status FROM Task WHERE Id = :t.Id];
  }
}
