/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
public class SendEmailLateTasksTest {
  @isTest
  static void sendEmail() {
    List<User> Usuario = [
      SELECT Id, Name, Email, UserName, ManagerId
      FROM USER
      WHERE IsActive = TRUE AND ManagerId != ''
      LIMIT 1
    ];

    if (!Usuario.IsEmpty()) {
      for (User usr : Usuario) {
        Task Tarefa = new Task(
          Subject = 'Ligação de follow-up - Teste',
          OwnerId = usr.Id,
          Priority = 'Normal',
          ActivityDate = Date.Today() - 2
        );

        insert Tarefa;
      }

      SendEmailLateTasks.sendEmail(Usuario);
    }
  }
}
