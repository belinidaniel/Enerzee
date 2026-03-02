public class SendEmailSummaryTasks {
  @InvocableMethod
  public static void sendEmail(List<User> Usuarios) {
    TaskSlaDailySummaryService.runOwnerOpenSummary();
  }
}
