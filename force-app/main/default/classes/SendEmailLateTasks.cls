/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : SendEmailLateTasksTest
 **/
public class SendEmailLateTasks {
  @InvocableMethod
  public static void sendEmail(List<User> Usuarios) {
    TaskSlaDailySummaryService.runManagerOverdue();
  }
}
