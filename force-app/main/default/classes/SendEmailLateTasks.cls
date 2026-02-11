public class SendEmailLateTasks {

    @InvocableMethod
    public static void sendEmail(List<User> Usuarios) {
        TaskSlaDailySummaryService.runManagerOverdue();
    }
}