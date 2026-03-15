/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : SendEmailSummaryTasksTest
 **/
public class SendEmailSummaryTasks {
  @InvocableMethod
  public static void sendEmail(List<User> Usuarios) {
    TaskSlaDailySummaryService.runOwnerOpenSummary();
  }
}
